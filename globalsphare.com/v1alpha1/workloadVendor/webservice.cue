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

if parameter.dependencies != _|_ {
	for k, v in parameter.dependencies {
		"dependencies-\(k)": {
			apiVersion: "v1"
			kind:       "ConfigMap"
			metadata: {
				name:      "dependencies-\(k)"
				namespace: context.namespace
			}
			data: {
				"\(k)": v.host
			}
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
	if parameter.storage.capacity != "" {
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
		template: {
			metadata: labels: {
				app:      context.appName
				workload: context.workloadName
			}
			spec: {
				serviceAccountName: context.appName
				containers: [{
					name:  "main"
					image: parameter.image
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
							limits:
								cpu: parameter.cpu
							requests:
								cpu: parameter.cpu
						}
					}
					ports: [{
						containerPort: parameter.port
					}]
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
							mountPath: "/etc/configs/userconfigs"
							subPath:   "userconfigs"
						},

						if parameter.dependencies != _|_
						for k, v in parameter.dependencies {
							name:      "dependencies-\(k)"
							mountPath: "/etc/configs/\(k)"
							subPath:   "\(k)"
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
				if parameter.dependencies != _|_
				for k, v in parameter.dependencies {
					name: "dependencies-\(k)"
					configMap: name: "dependencies-\(k)"
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

service: {
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
			name: "http"
			port: 80
			if parameter.port != _|_ {
				targetPort: parameter.port
			}
		}]
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
if parameter.ingress != _|_ {
	"ingressgateway-http": {
		apiVersion: "networking.istio.io/v1alpha3"
		kind:       "Gateway"
		metadata: {
			name:      "\(context.namespace)-http"
			namespace: "island-system"
		}
		spec: {
			selector: istio: "ingressgateway"
			servers: [{
				port: {
					number:   80
					name:     "http"
					protocol: "HTTP"
				}
				hosts: [
					parameter.ingress.host,
				]
			}]
		}
	}
	"ingressgateway-https": {
		apiVersion: "networking.istio.io/v1alpha3"
		kind:       "Gateway"
		metadata: {
			name:      "\(context.namespace)-https"
			namespace: "island-system"
		}
		spec: {
			selector: istio: "ingressgateway"
			servers: [{
				port: {
					number:   443
					name:     "https"
					protocol: "HTTPS"
				}
				tls: {
					mode:              "SIMPLE"
					serverCertificate: "/etc/istio/ingressgateway-certs/tls.crt"
					privateKey:        "/etc/istio/ingressgateway-certs/tls.key"
				}
				hosts: [
					parameter.ingress.host,
				]
			}]
		}
	}

	"virtualservice-http": {
		apiVersion: "networking.istio.io/v1alpha3"
		kind:       "VirtualService"
		metadata: {
			name:      "\(context.appName)-http"
			namespace: context.namespace
		}
		spec: {
			hosts: ["*"]
			gateways: ["island-system/\(context.namespace)-http"]
			http: [{
				name: context.workloadName
				if parameter.ingress.http != _|_ {
					match: []
				}
				route: [{
					destination: {
						port: number: 80
						host: context.workloadName
					}
					headers: {
						request: {
							add: {
								"X-Forwarded-Host": parameter.ingress.host
							}
						}
					}
				}]
			}]
		}
	}
	"virtualservice-https": {
		apiVersion: "networking.istio.io/v1alpha3"
		kind:       "VirtualService"
		metadata: {
			name:      "\(context.appName)-https"
			namespace: context.namespace
		}
		spec: {
			hosts: ["*"]
			gateways: ["island-system/\(context.namespace)-https"]
			http: [{
				match: []
				route: [{
					destination: {
						host: context.workloadName
						port: {
							number: 80
						}
					}
					headers: {
						request: {
							add: {
								"X-Forwarded-Host": parameter.ingress.host
							}
						}
					}
				}]
			}]
		}
	}
}
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

if parameter.dependencies != _|_ {
	for k, v in parameter.dependencies {
		"dependencies-\(k)": {
			apiVersion: "v1"
			kind:       "ConfigMap"
			metadata: {
				name:      "dependencies-\(k)"
				namespace: context.namespace
			}
			data: {
				"\(k)": v.host
			}
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
	if parameter.storage.capacity != "" {
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
		template: {
			metadata: labels: {
				app:      context.appName
				workload: context.workloadName
			}
			spec: {
				serviceAccountName: context.appName
				containers: [{
					name:  "main"
					image: parameter.image
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
							limits:
								cpu: parameter.cpu
							requests:
								cpu: parameter.cpu
						}
					}
					ports: [{
						containerPort: parameter.port
					}]
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
							mountPath: "/etc/configs/userconfigs"
							subPath:   "userconfigs"
						},

						if parameter.dependencies != _|_
						for k, v in parameter.dependencies {
							name:      "dependencies-\(k)"
							mountPath: "/etc/configs/\(k)"
							subPath:   "\(k)"
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
				if parameter.dependencies != _|_
				for k, v in parameter.dependencies {
					name: "dependencies-\(k)"
					configMap: name: "dependencies-\(k)"
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

service: {
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
			name: "http"
			port: 80
			if parameter.port != _|_ {
				targetPort: parameter.port
			}
		}]
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
if parameter.ingress != _|_ {
	"ingressgateway-http": {
		apiVersion: "networking.istio.io/v1alpha3"
		kind:       "Gateway"
		metadata: {
			name:      "\(context.namespace)-http"
			namespace: "island-system"
		}
		spec: {
			selector: istio: "ingressgateway"
			servers: [{
				port: {
					number:   80
					name:     "http"
					protocol: "HTTP"
				}
				hosts: [
					parameter.ingress.host,
				]
			}]
		}
	}
	"ingressgateway-https": {
		apiVersion: "networking.istio.io/v1alpha3"
		kind:       "Gateway"
		metadata: {
			name:      "\(context.namespace)-https"
			namespace: "island-system"
		}
		spec: {
			selector: istio: "ingressgateway"
			servers: [{
				port: {
					number:   443
					name:     "https"
					protocol: "HTTPS"
				}
				tls: {
					mode:              "SIMPLE"
					serverCertificate: "/etc/istio/ingressgateway-certs/tls.crt"
					privateKey:        "/etc/istio/ingressgateway-certs/tls.key"
				}
				hosts: [
					parameter.ingress.host,
				]
			}]
		}
	}

	"virtualservice-http": {
		apiVersion: "networking.istio.io/v1alpha3"
		kind:       "VirtualService"
		metadata: {
			name:      "\(context.appName)-http"
			namespace: context.namespace
		}
		spec: {
			hosts: ["*"]
			gateways: ["island-system/\(context.namespace)-http"]
			http: [{
				name: context.workloadName
				if parameter.ingress.http != _|_ {
					match: []
				}
				route: [{
					destination: {
						port: number: 80
						host: context.workloadName
					}
					headers: {
						request: {
							add: {
								"X-Forwarded-Host": parameter.ingress.host
							}
						}
					}
				}]
			}]
		}
	}
	"virtualservice-https": {
		apiVersion: "networking.istio.io/v1alpha3"
		kind:       "VirtualService"
		metadata: {
			name:      "\(context.appName)-https"
			namespace: context.namespace
		}
		spec: {
			hosts: ["*"]
			gateways: ["island-system/\(context.namespace)-https"]
			http: [{
				match: []
				route: [{
					destination: {
						host: context.workloadName
						port: {
							number: 80
						}
					}
					headers: {
						request: {
							add: {
								"X-Forwarded-Host": parameter.ingress.host
							}
						}
					}
				}]
			}]
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
				workload: context.workloadName
			}
		}
		rules: [{
			from: [
				{source: namespace: [context.namespace]}
			]
			to: [{
				operation: {
					methods: ["GET", "POST", "DELETE", "PUT", "HEAD", "OPTIONS", "PATCH"]
				}
			}]
		}]
	}
}
