parameter: {
	rootpwd: string | "123456"
	storage: {
		capacity: string | "1Gi"
	}
	init: string
}
construct: "\(context.workloadName)-master-configmap": {
	apiVersion: "v1"
	kind:       "ConfigMap"
	metadata: {
		name:      "\(context.workloadName)-master"
		namespace: context.namespace
		labels: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
	}
	data: {
		"my.cnf": """
			[mysqld]
			log-bin = mysql-bin
			server-id = 100
			binlog_format=row
			gtid_mode=on
			enforce_gtid_consistency=on
			"""
		"init.sql": """
        \(parameter.init)
        """
	}
}

construct: "\(context.workloadName)-master-service-headless": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "\(context.workloadName)-master-headless"
		namespace: context.namespace
		labels: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
	}
	spec: {
		clusterIP: "None"
		ports: [{
			name: context.workloadName
			port: 3306
		}]
		selector: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
	}
}

construct: "\(context.workloadName)-master-service": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "\(context.workloadName)-master"
		namespace: context.namespace
		labels: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
	}
	spec: {
		ports: [{
			name: context.workloadName
			port: 3306
		}]
		selector: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
	}
}

construct: "\(context.workloadName)-service": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      context.workloadName
		namespace: context.namespace
		labels: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
	}
	spec: {
		ports: [{
			name: context.workloadName
			port: 3306
		}]
		selector: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
	}
}

construct: "\(context.workloadName)-master-statefulset": {
	apiVersion: "apps/v1"
	kind:       "StatefulSet"
	metadata: {
		name:      "\(context.workloadName)-master"
		namespace: context.namespace
	}
	spec: {
		selector: matchLabels: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
		serviceName: "\(context.workloadName)-master-headless"
		replicas:    1
		template: {
			metadata: labels: {
				app:      context.appName
				workload: context.workloadName
				item:     "\(context.workloadName)-master"
			}
			spec: {
				serviceAccountName: context.appName
				containers: [{
					name:  "main"
					image: "harbor1.zlibs.com/dockerhub/mysql:5.7"
					env: [{
						name:  "MYSQL_ROOT_PASSWORD"
						value: parameter.rootpwd
					}]
					ports: [{
						containerPort: 3306
						name:          "mysql"
					}]
					volumeMounts: [{
						name:      "\(context.workloadName)-master"
						mountPath: "/var/lib/mysql"
					}, {
						name:      "conf"
						mountPath: "/etc/mysql/conf.d/mysql.cnf"
						subPath:   "my.cnf"
					}, {
						name:      "conf"
						mountPath: "/docker-entrypoint-initdb.d/init.sql"
						subPath:   "init.sql"
					}]
					command: [
						"bash",
						"-c",
						"""
                  rm -rf /var/lib/mysql/lost+found
                  echo "start server!"
                  /usr/local/bin/docker-entrypoint.sh mysqld
                """,
					]
				}]
				volumes: [{
					name: "conf"
					configMap: name: "\(context.workloadName)-master"
				}]
			}
		}
		volumeClaimTemplates: [{
			metadata: name: "\(context.workloadName)-master"
			spec: {
				accessModes: ["ReadWriteOnce"]
				storageClassName: "rook-ceph-block"
				resources: requests: storage: parameter.storage.capacity
			}
		}]
	}
}
construct: "\(context.workloadName)-slave-configmap": {
	apiVersion: "v1"
	kind:       "ConfigMap"
	metadata: {
		name:      "\(context.workloadName)-slave"
		namespace: context.namespace
		labels: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-slave"
		}
	}
	data: {
		"my.cnf": """
			[mysqld]
			log-bin = mysql-bin
			binlog_format=row
			gtid_mode=on
			enforce_gtid_consistency=on
			"""
		"init.sql": """
        change master to master_host='\(context.workloadName)-master-0.\(context.workloadName)-master-headless', master_port=3306, master_user='root', master_password='\(parameter.rootpwd)', master_auto_position=1;
        start slave;
        """
	}
}

construct: "\(context.workloadName)-slave-service": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "\(context.workloadName)-slave"
		namespace: context.namespace
		labels: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-slave"
		}
	}
	spec: {
		ports: [{
			name: context.workloadName
			port: 3306
		}]
		selector: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-slave"
		}
	}
}

construct: "\(context.workloadName)-slave-service-headless": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "\(context.workloadName)-slave-headless"
		namespace: context.namespace
		labels: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-slave"
		}
	}
	spec: {
		clusterIP: "None"
		ports: [{
			name: context.workloadName
			port: 3306
		}]
		selector: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-slave"
		}
	}
}

construct: "\(context.workloadName)-slave-statefulset": {
	apiVersion: "apps/v1"
	kind:       "StatefulSet"
	metadata: {
		name:      "\(context.workloadName)-slave"
		namespace: context.namespace
	}
	spec: {
		selector: matchLabels: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-slave"
		}
		serviceName: "\(context.workloadName)-slave"
		replicas:    2
		template: {
			metadata: labels: {
				app:      context.appName
				workload: context.workloadName
				item:     "\(context.workloadName)-slave"
			}
			spec: {
				serviceAccountName: context.appName
				containers: [{
					name:  "main"
					image: "harbor1.zlibs.com/dockerhub/mysql:5.7"
					env: [{
						name:  "MYSQL_ROOT_PASSWORD"
						value: parameter.rootpwd
					}]
					ports: [{
						containerPort: 3306
						name:          "mysql"
					}]
					volumeMounts: [{
						name:      "\(context.workloadName)-slave"
						mountPath: "/var/lib/mysql"
					}, {
						name:      "conf"
						mountPath: "/etc/mysql/conf.d/mysql.cnf"
						subPath:   "my.cnf"
					}, {
						name:      "conf"
						mountPath: "/docker-entrypoint-initdb.d/init.sql"
						subPath:   "init.sql"
					}]
					command: [
						"bash",
						"-c",
						"""
                rm -rf /var/lib/mysql/lost+found
                until mysql -h \(context.workloadName)-master-0.\(context.workloadName)-master-headless -P 3306 -p\(parameter.rootpwd) -e \"SELECT 1\"; do sleep 1; done
                [[ `hostname` =~ -([0-9]+)$ ]] || exit 1
                ordinal=${BASH_REMATCH[1]}
                echo [mysqld] > /etc/mysql/conf.d/server-id.cnf
                echo server-id=$((101 + $ordinal)) >> /etc/mysql/conf.d/server-id.cnf
                echo "run mysql!!"
                /usr/local/bin/docker-entrypoint.sh mysqld
                """]
				}]
				volumes: [{
					name: "conf"
					configMap: name: "\(context.workloadName)-slave"
				}]
			}
		}
		volumeClaimTemplates: [{
			metadata: name: "\(context.workloadName)-slave"
			spec: {
				accessModes: ["ReadWriteOnce"]
				storageClassName: "rook-ceph-block"
				resources: requests: storage: parameter.storage.capacity
			}
		}]
	}
}
context: {
	appName:       string
	workloadName: string
	namespace:     string
}
parameter: {
	authorization?: [...{
		service:   string
		namespace: string
		resources?: [...{
			uri: string
			action: [...string]
		}]
	}]
	serviceEntry?: [...{
		name:     string
		host:     string
		address:  string
		port:     int
		protocol: string
	}]
	dependencies: [...{[string]: host: string}]
	userconfigs: string
	ingress?: {
		host: string
		path?: [...string]
	}
}

construct: namespace: {
	apiVersion: "v1"
	kind:       "Namespace"
	metadata: {
		name: context.namespace
		labels: {
			"istio-injection": "enabled"
		}
	}
}
construct: serviceAccount: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		name:      context.appName
		namespace: context.namespace
	}
}
construct: "default-authorizationPolicy": {
	apiVersion: "security.istio.io/v1beta1"
	kind:       "AuthorizationPolicy"
	metadata: {
		name:      context.namespace
		namespace: context.namespace
	}
	spec: {}
}
if parameter.serviceEntry != _|_ {
	for k, v in parameter.serviceEntry {
		"construct": "serviceEntry-\(context.workloadName)-to-\(v.name)": {
			apiVersion: "networking.istio.io/v1alpha3"
			kind:       "ServiceEntry"
			metadata: {
				name:      "\(context.workloadName)-to-\(v.name)"
				namespace: context.namespace
			}
			spec: {
				exportTo: ["."]
				hosts: [
					v.host,
				]
				if v.address != _|_ {
					addresses: [
						v.address,
					]
				}
				location: "MESH_EXTERNAL"
				ports: [
					{
						number:   v.port
						name:     "port-name"
						protocol: v.protocol
					},
				]
			}
		}
	}
}
if parameter.authorization != _|_ {
	for k, v in parameter.authorization {
		construct: "island-allow-\(context.namespace)-to-\(v.namespace)-\(v.service)": {
			apiVersion: "security.istio.io/v1beta1"
			kind:       "AuthorizationPolicy"
			metadata: {
				name:      "\(context.namespace)-to-\(v.namespace)-\(v.service)"
				namespace: v.namespace
			}
			spec: {
				action: "ALLOW"
				selector: {
					matchLabels: {
						workload: v.service
					}
				}
				rules: [
					{
						from: [
							{source: principals: ["cluster.local/ns/\(context.namespace)/sa/\(context.appName)"]},
						]
						if v.resources != _|_ {
							to: [
								for resource in v.resources {
									operation: {
										methods: resource.actions
										paths: [resource.uri]
									}
								},
							]
						}
					},
				]
			}
		}
	}
}
