#Functions for Kata tests, cluster level
include BushSlicer
require '/home/valiev/mygit/verification-tests/features/kata/test_constants'
require "/home/valiev/mygit/verification-tests/lib/world"
require 'json'

def getFipsStatus(nodeName)
		
	myworld = DefaultWorld.new()
	myworld.project(KATA_NAMESPACE)
	node_cmd = "cat /proc/sys/crypto/fips_enabled"
	@fips_status = node("#{nodeName}").host.exec_admin(node_cmd)
	if @fips_status[:stdout].to_s.include? "1"
		return false
  	else
		return true
  	end
end


def getClusterVersion()
        kata_ns ||= "openshift-sandboxed-containers-operator"
        project(kata_ns)
	begin
        	@version = admin.cli_exec(:get, resource: "clusterversion", n:kata_ns, o: "jsonpath='{.items[0].status.history[0].version}'")
		return @version[:stdout]
	rescue
		logger.error("Failed to get cluster version with error:#{@version[:stderr]}")
	end
end
	
def checkForNamespaceExistance(clusterObj, namespace: KATA_NAMESPACE)
	if clusterObj.namespacesList.to_s.include? namespace
		logger.info("#{namespace} namespace exists")
        	return true
        else
		logger.error("#{namespace} namespace doesn't exists")
                return false
        end
end

def checkForKataconfigExistance(clusterObj, kataconfig: DEFAULT_KATACONFIG)
        if clusterObj.kataconfigsList.to_s.include? kataconfig
		logger.info("#{kataconfig} kataconfig exists")
                return true
        else
		logger.error("#{kataconfig} kataconfig doen't exists")
                return false
        end
end

def checkForPodExistance(clusterObj, pod: DEFAULT_POD_NAME)
	if clusterObj.podList.to_s.include? pod
                logger.info("#{pod} pod exists")
                return true
        else
            	logger.error("#{pod} pod doesn't exists")
                return false
        end
end

def checkForPodRuntime(podName, nameSpaceName: KATA_NAMESPACE)
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
	@podsWithKataList = admin.cli_exec(:get, resource: "pods", n:nameSpaceName, o: "jsonpath='{.items[?(@.spec.runtimeClassName==\"kata\")].metadata.name}'")[:stdout]
	if @podsWithKataList.to_s.equal? "''"
		logger.info("There are no pods running with #{KATA_RUNTIME_NAME} engine")
		return false
	else
		logger.info("#{@podsWithKataList} running with #{KATA_RUNTIME_NAME} engine")
		return true
	end
end




def fullPreTestChecks(clusterObj)
  logger.info("==================================RUNNING PRE-TEST CHECKS=========================================")
  logger.info("Cluster type is:#{clusterObj.clusterEnv}")
  logger.info("Cluster version is:#{clusterObj.version}")
  logger.info("Total ammount of nodes:#{clusterObj.nodeAmmount}")
  logger.info("Total ammount of worker nodes:#{clusterObj.workerNodesAmmount}")
  logger.info("Total ammount of master nodes:#{clusterObj.masterNodesAmmount}")
  getFipsStatus(clusterObj.randomWorkerNodeName)
  if checkForNamespaceExistance(clusterObj) && checkForKataconfigExistance(clusterObj) && checkForPodsWithKataRuntime(clusterObj)
    return true
  else
    logger.error("====================================PRE-TEST CHECKS FAILED===========================================\n")
    return false
  end
end

def runMustGatherOnCluster(clusterObj)
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
  if @audit_logs_counter / clusterObj.workerNodesAmmount.to_i == 3
  	logger.info("There are #{@audit_logs_counter} Audit logs in must-gather bundle")
  	logger.info("#{@audit_logs_counter} Audit logs matches 3 audit logs for every worker node")
  else
	logger.info("#{@audit_logs_counter} audit logs doesn't match 3 audit logs for #{clusterObj.workerNodesAmmount.to_i} in must-gather bundle")
  end
  raise "Failed to run must-gather command" unless @result[:success]
end
