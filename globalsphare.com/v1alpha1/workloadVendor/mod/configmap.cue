import "mod/context"

parameter: {
	configs?: [...{
		path:     string
		subPath?: string
		data: [...{
			name:  string
			value: string
		}]
	}]
}
if parameter["configs"] != _|_ {
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
