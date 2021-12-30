parameter: {
	size:           *"1G" | string
	broker_num:     int | *3
	zookeeper_name: string
}

"\(context.workloadName)-kafka-headless-service": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "\(context.workloadName)-kafka-hs"
		namespace: context.namespace
		labels: {
			app: "\(context.workloadName)-kafka"
		}
	}
	spec: {
		ports: [{
			port: 9092
			name: "server"
		}]
		clusterIP: "None"
		selector: {
			app: "\(context.workloadName)-kafka"
		}
	}
}
"\(context.workloadName)-kafka-service": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      context.workloadName
		namespace: context.namespace
		labels: {
			app: "\(context.workloadName)-kafka"
		}
	}
	spec: {
		selector: {
			app: "\(context.workloadName)-kafka"
		}
		ports: [{
			name: "client"
			port: 9092
		}]
	}
}
"\(context.workloadName)-kafka-StatefulSet": {
	apiVersion: "apps/v1"
	kind:       "StatefulSet"
	metadata: {
		name:      "\(context.workloadName)-kafka"
		namespace: context.namespace
	}
	spec: {
		serviceName: "\(context.workloadName)-kafka-hs"
		replicas:    parameter.broker_num
		selector: {
			matchLabels: {
				app: "\(context.workloadName)-kafka"
			}
		}
		template: {
			metadata: {
				labels: {
					app: "\(context.workloadName)-kafka"
				}
			}
			spec: {
				serviceAccountName: context.appName
				containers: [{
					name:  "main"
					image: "registry.cn-hangzhou.aliyuncs.com/jaxzhai/k8skafka:v1"
					ports: [{
						containerPort: 9092
						name:          "server"
					}]
					command: [
						"sh",
						"-c",
						"exec kafka-server-start.sh /opt/kafka/config/server.properties --override broker.id=${HOSTNAME##*-} --override listeners=PLAINTEXT://:9092 --override zookeeper.connect=\(parameter.zookeeper_name)-0.\(parameter.zookeeper_name)-headless.\(context.namespace).svc.cluster.local:2181 --override log.dir=/var/lib/kafka --override auto.create.topics.enable=true --override auto.leader.rebalance.enable=true --override background.threads=10 --override compression.type=producer --override delete.topic.enable=true --override leader.imbalance.check.interval.seconds=300 --override leader.imbalance.per.broker.percentage=10 --override log.flush.interval.messages=9223372036854775807 --override log.flush.offset.checkpoint.interval.ms=60000 --override log.flush.scheduler.interval.ms=9223372036854775807 --override log.retention.bytes=-1 --override log.retention.hours=168 --override log.roll.hours=168 --override log.roll.jitter.hours=0 --override log.segment.bytes=1073741824 --override log.segment.delete.delay.ms=60000 --override message.max.bytes=1000012 --override min.insync.replicas=1 --override num.io.threads=8 --override num.network.threads=3 --override num.recovery.threads.per.data.dir=1 --override num.replica.fetchers=1 --override offset.metadata.max.bytes=4096 --override offsets.commit.required.acks=-1 --override offsets.commit.timeout.ms=5000 --override offsets.load.buffer.size=5242880 --override offsets.retention.check.interval.ms=600000 --override offsets.retention.minutes=1440  --override offsets.topic.compression.codec=0 --override offsets.topic.num.partitions=50 --override offsets.topic.replication.factor=3 --override offsets.topic.segment.bytes=104857600 -override queued.max.requests=500 --override quota.consumer.default=9223372036854775807 --override quota.producer.default=9223372036854775807 --override replica.fetch.min.bytes=1 --override replica.fetch.wait.max.ms=500 --override replica.high.watermark.checkpoint.interval.ms=5000  --override replica.lag.time.max.ms=10000 --override replica.socket.receive.buffer.bytes=65536 --override replica.socket.timeout.ms=30000 --override request.timeout.ms=30000 --override socket.receive.buffer.bytes=102400 --override socket.request.max.bytes=104857600 --override socket.send.buffer.bytes=102400 --override unclean.leader.election.enable=true --override zookeeper.session.timeout.ms=6000 --override zookeeper.set.acl=false  --override broker.id.generation.enable=true --override connections.max.idle.ms=600000 --override controlled.shutdown.enable=true --override controlled.shutdown.max.retries=3  --override controlled.shutdown.retry.backoff.ms=5000 --override controller.socket.timeout.ms=30000 --override default.replication.factor=1  --override fetch.purgatory.purge.interval.requests=1000 --override group.max.session.timeout.ms=300000  --override group.min.session.timeout.ms=6000 --override inter.broker.protocol.version=0.10.2-IV0 --override log.cleaner.backoff.ms=15000 --override log.cleaner.dedupe.buffer.size=134217728 --override log.cleaner.delete.retention.ms=86400000 --override log.cleaner.enable=true --override log.cleaner.io.buffer.load.factor=0.9 --override log.cleaner.io.buffer.size=524288 --override log.cleaner.io.max.bytes.per.second=1.7976931348623157E308 --override log.cleaner.min.cleanable.ratio=0.5 --override log.cleaner.min.compaction.lag.ms=0  --override log.cleaner.threads=1 --override log.cleanup.policy=delete  --override log.index.interval.bytes=4096 --override log.index.size.max.bytes=10485760 --override log.message.timestamp.difference.max.ms=9223372036854775807 --override log.message.timestamp.type=CreateTime --override log.preallocate=false --override log.retention.check.interval.ms=300000 --override max.connections.per.ip=2147483647 --override num.partitions=1 --override producer.purgatory.purge.interval.requests=1000 --override replica.fetch.backoff.ms=1000 --override replica.fetch.max.bytes=1048576 -override replica.fetch.response.max.bytes=10485760 --override reserved.broker.max.id=1000",
					]
					env: [{
						name:  "KAFKA_HEAP_OPTS"
						value: "-Xmx1G -Xms1G"
					}, {
						name:  "KAFKA_OPTS"
						value: "-Dlogging.level=INFO"
					}]
					volumeMounts: [{
						name:      "\(context.workloadName)-kafka"
						mountPath: "/var/lib/kafka"
					}]
				}]
			}
		}
		volumeClaimTemplates: [{
			metadata: {
				name: "\(context.workloadName)-kafka"
			}
			spec: {
				accessModes: ["ReadWriteOnce"]
				storageClassName: "rook-ceph-block"
				resources: requests: storage: parameter.size
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
						"workload": v.service
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
