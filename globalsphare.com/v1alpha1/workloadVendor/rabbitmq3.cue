parameter: {
	image:    *"rabbitmq:3-management" | string
	vhost:    *"my_vhost" | string
	user:     *"admin" | string
	password: *"123456" | string
	size:     *"1G" | string
}
"\(context.workloadName)-deployment": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		name:      context.workloadName
		namespace: context.namespace
	}
	spec: {
		selector: matchLabels: {
			app:      context.appName
			workload: context.workloadName
		}
		replicas: 1
		template: {
			metadata: labels: {
				app:      context.appName
				workload: context.workloadName
			}
			spec: {
				containers: [{
					name:  "main"
					image: parameter["image"]
					env: [{
						name:  "RABBITMQ_DEFAULT_VHOST"
						value: parameter["vhost"]
					}, {
						name:  "RABBITMQ_DEFAULT_USER"
						value: parameter["user"]
					}, {
						name:  "RABBITMQ_DEFAULT_PASS"
						value: parameter["password"]
					}]
				}]
				restartPolicy: "Always"
			}
		}
	}
}

"\(context.workloadName)-service": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      context.workloadName
		namespace: context.namespace
	}
	spec: {
		selector: {
			app:      context.appName
			workload: context.workloadName
		}
		ports: [{
			port: 1883
			name: "port-1833"
		}, {
			port: 4369
			name: "port-4369"
		}, {
			port: 5671
			name: "port-5671"
		}, {
			port: 5672
			name: "port-5672"
		}, {
			port: 8883
			name: "port-8883"
		}, {
			port: 15672
			name: "port-15672"
		}, {
			port: 25672
			name: "port-25672"
		}, {
			port: 61613
			name: "port-61613"
		}, {
			port: 61614
			name: "port-61614"
		}]
		type: "ClusterIP"
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
