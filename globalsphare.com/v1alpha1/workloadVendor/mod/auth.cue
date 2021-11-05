import "mod/context"

parameter: {
  authorization?: [...{
    service: string
    namespace: string
    resources?: [...{
      uri: string
      action: [...string]
    }]
  }]
  serviceentry?: [...{
    host: string
    port: int
    protocol: string
  }]
}

if parameter["serviceentry"] != _|_ {
  for k, v in parameter.serviceentry {
    outputs: "serviceentry-\(context.componentName)-\(v.host)": {
      apiVersion: "networking.istio.io/v1alpha3"
      kind: "ServiceEntry"
      metadata: {
        name: "\(context.componentName)-\(v.host)"
        namespace: context.namespace
      }
      spec: {
        exportTo: ["."]
        hosts: [
          v.host,
        ]
        location: "MESH_EXTERNAL"
        ports: [
          {
            number: v.port
            name: "port-name"
            protocol: v.protocol
          },
        ]
      }
    }
  }
}

if parameter["authorization"] != _|_ {
  for k, v in parameter.authorization {
    construct: "island-allow-\(context.namespace)-to-\(v.namespace)-\(v.service)": {
      apiVersion: "security.istio.io/v1beta1"
      kind: "AuthorizationPolicy"
      metadata: {
        name: "\(context.namespace)-to-\(v.namespace)-\(v.service)"
        namespace: v.namespace
      }
      spec: {
        action: "ALLOW"
        selector: {
          matchLabels: {
            "component": v.service
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
          }
        ]
      }
    }
  }
}
