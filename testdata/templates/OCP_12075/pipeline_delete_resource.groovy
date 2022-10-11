node{
    stage 'build'
    openshiftDeleteResourceByJsonYaml (apiURL: '<repl_env>', authToken: '', jsonyaml: '''{
	"kind": "DeploymentConfig",
	"apiVersion": "apps.openshift.io/v1",
	"metadata": {
		"name": "frontend"
	},
	"spec": {
		"strategy": {
			"type": "Rolling",
			"rollingParams": {
				"updatePeriodSeconds": 1,
				"intervalSeconds": 1,
				"timeoutSeconds": 120
			}
		},
		"triggers": [{
			"type": "ImageChange",
			"imageChangeParams": {
				"automatic": false,
				"containerNames": [
					"nodejs-helloworld"
				],
				"from": {
					"kind": "ImageStreamTag",
					"name": "origin-nodejs-sample:latest"
				}
			}
		}, {
			"type": "ConfigChange"
		}],
		"replicas": 1,
		"selector": {
			"name": "frontend"
		},
		"template": {
			"metadata": {
				"labels": {
					"name": "frontend"
				}
			},
			"spec": {
				"containers": [{
					"name": "nodejs-helloworld",
					"image": " ",
					"ports": [{
						"containerPort": 8080,
						"protocol": "TCP"
					}],
					"resources": {
						"limits": {
							"memory": "${MEMORY_LIMIT}"
						}
					},
					"terminationMessagePath": "/dev/termination-log",
					"imagePullPolicy": "IfNotPresent",
					"securityContext": {
						"capabilities": {},
						"privileged": false
					}
				}],
				"restartPolicy": "Always",
				"dnsPolicy": "ClusterFirst"
			}
		}
	}
}''', namespace: '<repl_ns>' )
    openshiftDeleteResourceByLabels( apiURL: '<repl_env>', authToken: '', keys: 'name', namespace: '<repl_ns>', types: 'build', values: 'nodejs-sample-build', verbose: 'false' )
    openshiftDeleteResourceByKey( apiURL: '<repl_env>', authToken: '', keys: 'origin-nodejs-sample', namespace: '<repl_ns>', types: 'is' )
}
