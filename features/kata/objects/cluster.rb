class ClusterObj
  include BushSlicer
  require "/home/valiev/mygit/verification-tests/lib/world"
  require "/home/valiev/mygit/verification-tests/lib/log"
  require "/home/valiev/mygit/verification-tests/features/kata/test_functions/cluster"
  require "/home/valiev/mygit/verification-tests/features/kata/test_functions/kataconfig"
  require "/home/valiev/mygit/verification-tests/features/kata/test_constants"
  require "/home/valiev/mygit/verification-tests/features/kata/objects/node"
  require 'net/http'
  require 'json'
  #attr_reader :uri, :token
  attr_accessor :data, :nodeAmmount, :nodes, :workerNodesAmmount, :masterNodesAmmount, :uri, :logger, :version, :clusterEnv, :randomWorkerNodeName, 
		:kataconfigsList, :podsList, :namespacesList, :fipsStatus, :nodeNamesList, :nodesList

  def initialize()
        myworld = DefaultWorld.new()
	@logger = Logger.new()
	@admin = myworld.admin
        myworld.project(KATA_NAMESPACE)
        @uri = @admin.cli_exec(:get, resource: "infrastructure", n:KATA_NAMESPACE, o: "jsonpath='{..status.apiServerURL}'")[:stdout]
	@version = @admin.cli_exec(:get, resource: "clusterversion", n:KATA_NAMESPACE, o: "jsonpath='{.items[0].status.history[0].version}'")[:stdout]
	@datajs = @admin.cli_exec(:get, resource: "nodes", n:KATA_NAMESPACE, o: "json")
 	@data = JSON.parse(@datajs[:stdout])
  	@clusterEnv = @admin.cli_exec(:get, resource: "infrastructure", n:KATA_NAMESPACE, o: "jsonpath='{..status.platform}'")[:stdout]
  	@nodeAmmount = @data['items'].count
  	@workerNodesAmmount = 0
  	@masterNodesAmmount = 0
	@randomWorkerNodeName = ""
	@nodeNamesList = (@admin.cli_exec(:get, resource: "nodes", o: "jsonpath='{..metadata.name}'")[:stdout]).split(" ")
	@nodesList = getNodeObjects()
	puts @nodesList[0].uid
	getNodesType()
	@namespacesList = @admin.cli_exec(:get, resource: "namespace")[:stdout]
	@kataconfigsList = @admin.cli_exec(:get, resource: "kataconfig")[:stdout]
	@podsList = (@admin.cli_exec(:get, resource: "pods")[:stdout]).split(" ")
	@fipsStatus = myworld.node("#{randomWorkerNodeName}").host.exec_admin(NODE_CMD_FOR_FIPS)[:stdout]
	puts "KATA completed nodes"
	puts getKataCompletedNodesLIst()
	#@podsWithKataList = @admin.cli_exec(:get, resource: "pods", n:nameSpaceName, o: "jsonpath='{.items[?(@.spec.runtimeClassName==\"kata\")].metadata.name}'")
  end; nil
  
  def getNodesType()
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
	nodesList = []
	self.nodeNamesList.each do |node|
		node = node.delete("'")
        	nodeObj = NodeObj.new(node)
        	nodesList.push(nodeObj)
        end
   	return nodesList
  end
  #puts @nodesList

  
end; nil
