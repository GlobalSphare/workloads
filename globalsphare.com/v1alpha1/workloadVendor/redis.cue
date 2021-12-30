parameter: {
}
"\(context.appName)-configmap": {
	apiVersion: "v1"
	kind:       "ConfigMap"
	metadata: {
		name:      "\(context.appName)-redis-conf"
		namespace: context.namespace
	}
	data: {
		master: """
			pidfile /var/run/redis.pid
			port 6379
			bind 0.0.0.0
			timeout 3600
			tcp-keepalive 1
			loglevel verbose
			logfile /data/redis.log
			slowlog-log-slower-than 10000
			slowlog-max-len 128
			databases 16
			protected-mode no
			save \"\"
			appendonly no

			"""

		slave: """
        pidfile /var/run/redis.pid
        port 6379
        bind 0.0.0.0
        timeout 3600
        tcp-keepalive 1
        loglevel verbose
        logfile /data/redis.log
        slowlog-log-slower-than 10000
        slowlog-max-len 128
        databases 16
        protected-mode no
        save \"\"
        appendonly no
        slaveof \(context.workloadName)-master 6379
        """
	}
}

"\(context.workloadName)-service-master": {
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
			port: 6379
		}]
		selector: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
	}
}

"\(context.workloadName)-service-master-headless": {
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
			port: 6379
		}]
		selector: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
	}
}

"\(context.workloadName)-service": {
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
			port: 6379
		}]
		selector: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-master"
		}
	}
}

"\(context.workloadName)-statefulset-master": {
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
		serviceName: context.workloadName
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
					image: "harbor1.zlibs.com/dockerhub/redis:6.2.4"
					ports: [{
						containerPort: 6379
						name:          "redis"
					}]
					command: [
						"redis-server",
						"/etc/redis/redis.conf",
					]
					volumeMounts: [{
						name:      "redis-conf"
						mountPath: "/etc/redis/redis.conf"
						subPath:   "master"
					}]
				}]
				volumes: [{
					name: "redis-conf"
					configMap: name: "\(context.appName)-redis-conf"
				}]
			}
		}
	}
}

"\(context.workloadName)-slave-service": {
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
			port: 6379
		}]
		selector: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-slave"
		}
	}
}

"\(context.workloadName)-slave-service-headless": {
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
			name: "\(context.workloadName)"
			port: 6379
		}]
		selector: {
			app:      context.appName
			workload: context.workloadName
			item:     "\(context.workloadName)-slave"
		}
	}
}

"\(context.workloadName)-slave-statefulset": {
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
		serviceName: context.workloadName
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
					name:  "\(context.workloadName)-slave"
					image: "harbor1.zlibs.com/dockerhub/redis:6.2.4"
					ports: [{
						containerPort: 6379
						name:          "redis"
					}]
					command: [
						"bash",
						"-c",
						"""
                until [ \"$(echo 'set check_status 1'|timeout 3 redis-cli -h \(context.workloadName)-master)\" = \"OK\" ];do sleep 4s;echo \"waiting for the master ready\";done
                redis-server /etc/redis/redis.conf
                """]
					volumeMounts: [{
						name:      "redis-conf"
						mountPath: "/etc/redis/redis.conf"
						subPath:   "slave"
					}]
				}]
				volumes: [{
					name: "redis-conf"
					configMap: name: "\(context.appName)-redis-conf"
				}]
			}
		}
	}
}
context: {
	appName:      string
	workloadName: string
	namespace:    string
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
		address?: string
		port:     int
		protocol: string
	}]
	dependencies?: [string]: host: string
	userconfigs?: string | *"{}"
	ingress?: {
		host: string
		path?: [...string]
	}
}

namespace: {
	apiVersion: "v1"
	kind:       "Namespace"
	metadata: {
		name: context.namespace
		labels: {
			"istio-injection": "enabled"
		}
	}
}
serviceAccount: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		name:      context.appName
		namespace: context.namespace
	}
}
"default-authorizationPolicy": {
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
		"serviceEntry-\(context.workloadName)-to-\(v.name)": {
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
		"island-allow-\(context.namespace)-to-\(v.namespace)-\(v.service)": {
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
"\(context.workloadName)-viewer": {
	apiVersion: "security.istio.io/v1beta1"
	kind:       "AuthorizationPolicy"
	"metadata": {
		name:      "\(context.workloadName)-viewer"
		namespace: context.namespace
	}
	spec: {
		selector: {
			matchLabels: {
				app:      context.appName
				workload: context.workloadName
			}
		}
		rules: [{
			from: [{
				source: {
					namespaces: [context.namespace]
				}
			}]
			to: [{
				operation: {
					methods: ["GET", "POST", "DELETE", "PUT", "HEAD", "OPTIONS", "PATCH"]
				}
			}]
		}]
	}
}
