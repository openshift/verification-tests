#Functions for Kata tests, cluster level
include BushSlicer
require 'verification-tests/features/kata/test_constants'
require "verification-tests/lib/world"
require 'json'

def getFipsStatus(nodeName, namespace: KATA_NAMESPACE)
#Getting fips status from worker node 
#namespace: cluster namespace to check in default:'openshift-sandboxed-containers-operator' type: string
#nodeName: node name to check type: string
#return: true if fips enabled, false if not type: boolean
		
	myworld = DefaultWorld.new()
	myworld.project(namespace)
	@fips_status = myworld.node("#{nodeName}").host.exec_admin(NODE_CMD_FOR_FIPS)
	if @fips_status[:stdout].to_s.include? "1"
		return false
  	else
		return true
  	end
end


def getClusterVersion()
#Getting cluster openshift version 
#parameters: none
#return: version type: string

	myworld = DefaultWorld.new()
        myworld.project(KATA_NAMESPACE)
	@admin = myworld.admin
	begin
        	@version = @admin.cli_exec(:get, resource: "clusterversion", n:KATA_NAMESPACE, o: "jsonpath='{.items[0].status.history[0].version}'")
		return @version[:stdout]
	rescue
		logger.error("Failed to get cluster version with error:#{@version[:stderr]}")
	end
end
	
def checkForNamespaceExistance(clusterObj, namespace: KATA_NAMESPACE)
#Checking if namespace exists on cluster 
#clusterObj: cluster object type:ClusterObj
#namespace: cluster namespace to check in default:'openshift-sandboxed-containers-operator' type: string
#return: true if namespace exists, false if not type: boolean

	if clusterObj.namespacesList.to_s.include? namespace
		logger.info("#{namespace} namespace exists")
        	return true
        else
		logger.error("#{namespace} namespace doesn't exists")
                return false
        end
end

def checkForKataconfigExistance(clusterObj, kataconfig: DEFAULT_KATACONFIG)
#Checking if kataconfig exists on cluster 
#clusterObj: cluster object type:ClusterObj
#kataconfig: cluster kataconfig to check in default:'example-kataconfig' type: string
#return: true if namespace exists, false if not type: boolean

        if clusterObj.kataconfigsList.to_s.include? kataconfig
		logger.info("#{kataconfig} kataconfig exists")
                return true
        else
		logger.error("#{kataconfig} kataconfig doen't exists")
                return false
        end
end

def checkForPodExistance(clusterObj, pod: DEFAULT_POD_NAME)
#Checking if pod exists on cluster 
#clusterObj: cluster object type:ClusterObj
#pod: cluster pod to check in default:'example' type: string
#return: true if namespace exists, false if not type: boolean

	if clusterObj.podList.to_s.include? pod
                logger.info("#{pod} pod exists")
                return true
        else
            	logger.error("#{pod} pod doesn't exists")
                return false
        end
end

def checkForPodRuntime(podName, nameSpaceName: KATA_NAMESPACE)
#Checking for pod runtime engine is kata
#podName: pod name to check type: string
#namespace: cluster namespace to check in default:'openshift-sandboxed-containers-operator' type: string
#return: true if pod running with kata, false if not type: boolean

	if checkForPodExistance(clusterObj)
		runtimeResult = admin.cli_exec(:get, resource: "pods/#{podName}", n:nameSpaceName, o: "jsonpath='{.spec.runtimeClassName}'")[:stdout]   
                if runtimeResult.to_s.include? KATA_RUNTIME_NAME
			logger.info("#{pod} is running with #{KATA_RUNTIME_NAME} engine")
                	return true
		else
			logger.info("#{pod} is not running with #{KATA_RUNTIME_NAME} engine")
		end
        else
                return false
        end
end

def checkForPodsWithKataRuntime(clusterObj, nameSpaceName: KATA_NAMESPACE)
#Checking if there are pods with kata on cluster 
#clusterObj: cluster object type:ClusterObj
#namespace: cluster namespace to check in default:'openshift-sandboxed-containers-operator' type: string
#return: true there are pods with kata runtime, false if not type: boolean

	@podsWithKataList = admin.cli_exec(:get, resource: "pods", n:nameSpaceName, o: "jsonpath='{.items[?(@.spec.runtimeClassName==\"kata\")].metadata.name}'")[:stdout]
	if @podsWithKataList.to_s.include? "''"
		logger.info("There are no pods running with #{KATA_RUNTIME_NAME} engine")
		return false
	else
		logger.info("#{@podsWithKataList} running with #{KATA_RUNTIME_NAME} engine")
		return true
	end
end




def fullPreTestChecks(clusterObj)
#Checking for kata operator installed, kataconfig deployed and at least 1 pod with kata is running
#clusterObj: cluster object type:ClusterObj
#return: true if all checks passed, false if not type: boolean

  logger.info("==================================RUNNING PRE-TEST CHECKS=========================================")
  logger.info("Cluster type is:#{clusterObj.clusterEnv}")
  logger.info("Cluster version is:#{clusterObj.version}")
  logger.info("Total ammount of nodes:#{clusterObj.nodeAmmount}")
  logger.info("Total ammount of worker nodes:#{clusterObj.workerNodesAmmount}")
  logger.info("Total ammount of master nodes:#{clusterObj.masterNodesAmmount}")
#TODO move getFipsStatus to a separate file
  getFipsStatus(clusterObj.randomWorkerNodeName)
  if checkForNamespaceExistance(clusterObj) && checkForKataconfigExistance(clusterObj) && checkForPodsWithKataRuntime(clusterObj)
    return true
  else
    logger.error("====================================PRE-TEST CHECKS FAILED===========================================\n")
    return false
  end
end

def runMustGatherOnCluster(clusterObj)
#Running must gather on cluster and checking for cri-o and audit logs existance 
#clusterObj: cluster object type:ClusterObj
#return: none
#TODO move to a separate test_functions file
  logger.info("==================================TEST IS RUNNING=========================================")
  logger.info("Running must-gather command")
  @result = env.admin.cli_exec(:oadm_must_gather, image:DEFAULT_MUST_GATHER_IMAGE)
  pods_json = ''
  @crioLogsResult = false
  @auditLogsResult = false
  dc_output = @result[:stdout]
  @crio_logs_counter = 0
  @audit_logs_counter = 0
  logger.info("\nMust-gather image is:#{DEFAULT_MUST_GATHER_IMAGE}")
  if dc_output.to_s.include? "logs_crio"
    logger.info("CRI-O logs are in must-gather bundle")
    dc_output.each_line do |line|
      if line.to_s.include? "logs_crio"
        @crio_logs_counter += 1
      end
    end
  end
#TODO move to must gather test_functions file
  if @crio_logs_counter == clusterObj.masterNodesAmmount.to_i + clusterObj.workerNodesAmmount.to_i
	logger.info("There are #{@crio_logs_counter} CRI-O logs in must-gather bundle")
  	logger.info("#{@crio_logs_counter} CRI-O logs matches #{clusterObj.masterNodesAmmount.to_i + clusterObj.workerNodesAmmount.to_i}  node cluster")
	@crioLogsResult = true
  else
	logger.info("There are no CRI-O logs in must-gather bundle")
  end
  if dc_output.to_s.include? "audit.log"
    logger.info("Audit logs are in must-gather bundle")
    dc_output.each_line do |line|
      if line.to_s.include? "audit.log"
        #logger.info(line)
        @audit_logs_counter += 1
      end
    end
  end
#TODO move to must gather test_functions file
  if @audit_logs_counter / clusterObj.workerNodesAmmount.to_i == 3
  	logger.info("There are #{@audit_logs_counter} Audit logs in must-gather bundle")
  	logger.info("#{@audit_logs_counter} Audit logs matches 3 audit logs for every worker node")
  else
	logger.info("#{@audit_logs_counter} audit logs doesn't match 3 audit logs for #{clusterObj.workerNodesAmmount.to_i} in must-gather bundle")
  end
  raise "Failed to run must-gather command" unless @result[:success]
end
