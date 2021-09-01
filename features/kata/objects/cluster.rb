class ClusterObj
#Class for openshift cluster object, to be used in tests
  include BushSlicer
  require "/verification-tests/lib/world.rb"
  require "verification-tests/lib/log"
  require "verification-tests/features/kata/test_functions/cluster"
  require "verification-tests/features/kata/test_functions/kataconfig"
  require "verification-tests/features/kata/test_constants"
  require "verification-tests/features/kata/objects/node"
  require 'net/http'
  require 'json'
  #attr_reader :uri, :token
  attr_accessor :data, :nodeAmmount, :nodes, :workerNodesAmmount, :masterNodesAmmount, :uri, :logger, :version, :clusterEnv, :randomWorkerNodeName, 
		:kataconfigsList, :podsList, :namespacesList, :fipsStatus, :nodeNamesList, :nodesList

  def initialize()
#myworld: cucushift default class type:bushslicer default class object
#logger: cucushift logs class type:bushslicer default log class object
#admin: cli class type: bushslicer default cli class object
#uri: cluster host
# uri type: string
#version: openshift cluster version type: string
#data: cluster nodes info type:json
#clusterEnv: cluster type (e.g. GCP, AZURE) type: string
#nodeAmmount: total cluster nodes amount type: int
#workerNodesAmmount: worker nodes amount type:int
#masterNodesAmmount: master nodes amount typr: int
#randomWorkerNodeName: random worker node name type: string
#nodeNamesList: list of cluster node names type: array
#nodesList: list of cluster node objects type: NodeObj
#TODO convert namespacesList to array
#namespacesList: list of cluster namespaces type: string
#TODO convert kataconfigsList to array
#kataconfigsList: list of cluster kataconfigs type: string
#podsList:l list of cluster pods type: array
#fipsStatus: fips enabled("1")/disabled("0") type: string

        myworld = DefaultWorld.new()
	@logger = Logger.new()
	@admin = myworld.admin
        myworld.project(KATA_NAMESPACE)
        @uri = @admin.cli_exec(:get, resource: "infrastructure", n:KATA_NAMESPACE, o: "jsonpath='{..status.apiServerURL}'")[:stdout]
	@version = getClusterVersion()
	@datajs = @admin.cli_exec(:get, resource: "nodes", n:KATA_NAMESPACE, o: "json")
 	@data = JSON.parse(@datajs[:stdout])
  	@clusterEnv = @admin.cli_exec(:get, resource: "infrastructure", n:KATA_NAMESPACE, o: "jsonpath='{..status.platform}'")[:stdout]
  	@nodeAmmount = @data['items'].count
  	@workerNodesAmmount = 0
  	@masterNodesAmmount = 0
	@randomWorkerNodeName = ""
	@nodeNamesList = (@admin.cli_exec(:get, resource: "nodes", o: "jsonpath='{..metadata.name}'")[:stdout]).split(" ")
	@nodesList = getNodeObjects()
	getNodesType()
	@namespacesList = @admin.cli_exec(:get, resource: "namespace")[:stdout]
	@kataconfigsList = @admin.cli_exec(:get, resource: "kataconfig")[:stdout]
	@podsList = (@admin.cli_exec(:get, resource: "pods")[:stdout]).split(" ")
	@fipsStatus = getFipsStatus(@randomWorkerNodeName)
  end; nil
  
  def getNodesType()
#Counting master and nodes amount and assigns random worker node name
#parameters: none
#return: none
	 self.nodeNamesList.each do |node|
		node = node.delete("'")
    		if node.to_s.include? 'master'
      			self.masterNodesAmmount += 1
    		else
			self.randomWorkerNodeName = node
      			self.workerNodesAmmount += 1
    		end
  	end
  end;nil
  
  def getNodeObjects()
#Creating list of node objects
#parameters: none
#return: nodeList type: list of NodeObj

	nodesList = []
	self.nodeNamesList.each do |node|
		node = node.delete("'")
        	nodeObj = NodeObj.new(node)
        	nodesList.push(nodeObj)
        end
   	return nodesList
  end
end; nil
