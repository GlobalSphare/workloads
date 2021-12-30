package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"strings"
)
type def struct {
	Source string
	Name string
	Ver string
	Path string
}

func main() {
	sql := ""
	workload := make([]def, 0)

	//type
	workload = append(workload, def{"workloadType","webservice","aam.globalsphare.com/v1alpha1","workloadType/webservice.yaml"})
	workload = append(workload, def{"workloadType","worker","aam.globalsphare.com/v1alpha1","workloadType/worker.yaml"})
	workload = append(workload, def{"workloadType","mysql","aam.globalsphare.com/v1alpha1","workloadType/mysql.yaml"})
	workload = append(workload, def{"workloadType","mysql-bare","aam.globalsphare.com/v1alpha1","workloadType/mysql-bare.yaml"})
	workload = append(workload, def{"workloadType","redis","aam.globalsphare.com/v1alpha1","workloadType/redis.yaml"})
	workload = append(workload, def{"workloadType","kafka","aam.globalsphare.com/v1alpha1","workloadType/kafka.yaml"})
	workload = append(workload, def{"workloadType","rabbitmq","aam.globalsphare.com/v1alpha1","workloadType/rabbitmq.yaml"})
	workload = append(workload, def{"workloadType","zookeeper","aam.globalsphare.com/v1alpha1","workloadType/zookeeper.yaml"})

	//vendor
	workload = append(workload, def{"workloadVendor","webservice","aam.globalsphare.com/v1alpha1","workloadVendor/webservice.yaml"})
	workload = append(workload, def{"workloadVendor","worker","aam.globalsphare.com/v1alpha1","workloadVendor/worker.yaml"})
	workload = append(workload, def{"workloadVendor","mysql","aam.globalsphare.com/v1alpha1","workloadVendor/mysql.yaml"})
	workload = append(workload, def{"workloadVendor","mysql-bare","aam.globalsphare.com/v1alpha1","workloadVendor/mysql-bare.yaml"})
	workload = append(workload, def{"workloadVendor","redis","aam.globalsphare.com/v1alpha1","workloadVendor/redis.yaml"})
	workload = append(workload, def{"workloadVendor","kafka","aam.globalsphare.com/v1alpha1","workloadVendor/kafka.yaml"})
	workload = append(workload, def{"workloadVendor","rabbitmq","aam.globalsphare.com/v1alpha1","workloadVendor/rabbitmq3.yaml"})
	workload = append(workload, def{"workloadVendor","rabbitmq-ceph","aam.globalsphare.com/v1alpha1","workloadVendor/rabbitmq3-ceph.yaml"})
	workload = append(workload, def{"workloadVendor","rabbitmq-plugins","aam.globalsphare.com/v1alpha1","workloadVendor/rabbitmq3-plugins.yaml"})
	workload = append(workload, def{"workloadVendor","rabbitmq-plugins-ceph","aam.globalsphare.com/v1alpha1","workloadVendor/rabbitmq3-plugins-ceph.yaml"})
	workload = append(workload, def{"workloadVendor","zookeeper","aam.globalsphare.com/v1alpha1","workloadVendor/zookeeper.yaml"})

	//trait
	workload = append(workload, def{"trait","ingress","aam.globalsphare.com/v1alpha1","trait/ingress.yaml"})

	for _,v := range workload {
		b, err := ioutil.ReadFile(v.Path)
		if err != nil {
			fmt.Println(err)
			return
		}
		s, err := json.Marshal(string(b))
		if err != nil {
			fmt.Println(err)
			return
		}
		tableName := ""
		if v.Source == "workloadType" {
			tableName = "t_type"
		}else if v.Source == "workloadVendor"{
			tableName = "t_vendor"
		}else{
			tableName = "t_trait"
		}
		title := fmt.Sprintf("# %s/%s/%s\n",v.Ver,v.Source, v.Name )
		sql += title + fmt.Sprintf("insert into %s(`name`, `ver`,`value`)values(\"%s\", \"%s\", %s);\n",tableName, v.Name, v.Ver, string(s))
	}
	sql = strings.ReplaceAll(sql, "\\u003e", ">")
	ioutil.WriteFile("workloads.sql", []byte(sql),0644)
}