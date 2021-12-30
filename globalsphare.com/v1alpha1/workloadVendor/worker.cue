parameter: {
	image: string
	port:  *80 | int
	cmd?: [...string]
	args?: [...string]
	cpu?: string
	env?: [...{
		name:   string
		value?: string
		valueFrom?: {
			secretKeyRef: {
				name: string
				key:  string
			}
		}
	}]
	configs?: [...{
		path:     string
		subPath?: string
		data: [...{
			name:  string
			value: string
		}]
	}]
	storage?: {
		capacity: string
		path:     string
	}
}
if parameter.userconfigs != _|_ {
	userconfigs: {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "userconfigs"
			namespace: context.namespace
		}
		data: {
			userconfigs: parameter.userconfigs
		}
	}
}

if parameter.configs != _|_ {
	for k, v in parameter.configs {
		"island-\(context.workloadName)-\(k)": {
			apiVersion: "v1"
			kind:       "ConfigMap"
			metadata: {
				name:      "\(context.workloadName)-\(k)"
				namespace: context.namespace
			}
			data: {
				for _, vv in v.data {
					if vv.name != "island-info" {
						"\(vv.name)": vv.value
					}
				}
			}
		}
	}
}
if parameter.storage != _|_ {
	if parameter.storage.capacity != _|_ {
		storage: {
			apiVersion: "v1"
			kind:       "PersistentVolumeClaim"
			metadata: {
				name:      "storage-\(context.workloadName)"
				namespace: context.namespace
			}
			spec: {
				storageClassName: "rook-ceph-block"
				accessModes: [
					"ReadWriteOnce",
				]
				resources: requests: storage: parameter.storage.capacity
			}
		}
	}
}
statefulsetheadless: {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "\(context.workloadName)-headless"
		namespace: context.namespace
		labels: {
			workload: context.workloadName
			app:      context.appName
		}
	}
	spec: {
		clusterIP: "None"
		selector: {
			workload: context.workloadName
			app:      context.appName
		}
	}
}

"\(context.workloadName)-statefulset": {
	apiVersion: "apps/v1"
	kind:       "StatefulSet"
	metadata: {
		name:      context.workloadName
		namespace: context.namespace
	}
	spec: {
		selector: matchLabels: {
			app:      context.appName
			workload: context.workloadName
		}
		replicas:    1
		serviceName: "\(context.workloadName)-headless"
		template: {
			metadata: labels: {
				"app":      context.appName
				"workload": context.workloadName
			}
			spec: {
				serviceAccountName: context.appName
				containers: [{
					name:            context.workloadName
					image:           parameter.image
					imagePullPolicy: "Always"
					if parameter.cmd != _|_ {
						command: parameter.cmd
					}
					if parameter.args != _|_ {
						args: parameter.args
					}
					if parameter.env != _|_ {
						env: parameter.env
					}
					if parameter.cpu != _|_ {
						resources: {
							limits: cpu:   parameter.cpu
							requests: cpu: parameter.cpu
						}
					}
					volumeMounts: [
						if parameter.configs != _|_
						for k, v in parameter.configs if v.subPath != _|_ {
							name:      "\(context.workloadName)-\(k)"
							mountPath: "\(v.path)/\(v.subPath)"
							subPath:   v.subPath
						},
						if parameter.configs != _|_
						for k, v in parameter.configs if v.subPath == _|_ {
							name:      "\(context.workloadName)-\(k)"
							mountPath: v.path
						},
						if parameter.userconfigs != _|_ {
							name:      "userconfigs"
							mountPath: "/etc/configs"
						},
						if parameter.storage != _|_
						if parameter.storage.capacity != "" {
							name:      "storage-\(context.workloadName)"
							mountPath: parameter.storage.path
						},

					]
				}]
				volumes: [
					if parameter.configs != _|_
					for k, v in parameter.configs if v.subPath != _|_ {
						name: "\(context.workloadName)-\(k)"
						configMap: name: "\(context.workloadName)-\(k)"
					},
					if parameter.configs != _|_
					for k, v in parameter.configs if v.subPath == _|_ {
						name: "\(context.workloadName)-\(k)"
						configMap: name: "\(context.workloadName)-\(k)"
					},
					if parameter.userconfigs != _|_ {
						name: "userconfigs"
						configMap: name: "userconfigs"
					},
					if parameter.storage != _|_
					if parameter.storage.capacity != "" {
						name: "storage-\(context.workloadName)"
						persistentVolumeClaim: claimName: "storage-\(context.workloadName)"
					},

				]
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
				rules: [{
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
				}]
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
		action: "ALLOW"
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
