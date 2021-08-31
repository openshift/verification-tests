class NodeObj
  include BushSlicer
  require "/home/valiev/mygit/verification-tests/lib/world"
  require "/home/valiev/mygit/verification-tests/lib/log"
  require "/home/valiev/mygit/verification-tests/features/kata/test_functions/cluster"
  require "/home/valiev/mygit/verification-tests/features/kata/test_constants"
  require 'net/http'
  require 'json'
  attr_reader :name
  attr_accessor :name, :uid, :labels, :networkUnavailable, :memoryPressure, :diskPressure, :pIDPressure, :ready, :conditions, :datajs, :data

  def initialize(name)
	puts name
        myworld = DefaultWorld.new()
	#@logger = Logger.new()
	@admin = myworld.admin
        myworld.project(KATA_NAMESPACE)
	@name = name
	@uid = (@admin.cli_exec(:get, resource: "nodes/#{@name}", o: "jsonpath='{.metadata.uid}'")[:stdout])
	@labels = (@admin.cli_exec(:get, resource: "nodes/#{@name}", o: "jsonpath='{.metadata.labels}'")[:stdout]).split(" ")
	@networkUnavailable = "NetworkUnavailable"
	@memoryPressure = "MemoryPressure"
	@diskPressure = "DiskPressure"
	@pIDPressure = "PIDPressure"
	@ready = "Ready"
	@conditions = @admin.cli_exec(:get, resource: "nodes/#{@name}", o: "jsonpath='{..status.conditions}'")[:stdout]
 	@conditions = @conditions.delete("'")
	#@conditions = @admin.cli_exec(:get, resource: "nodes", o: "json")[:stdout]
	#@datajs = @admin.cli_exec(:get, resource: "nodes", n:KATA_NAMESPACE, o: "json")
        #@data = JSON.parse(@datajs[:stdout])
	#@datajs = @admin.cli_exec(:get, resource: "nodes", n:KATA_NAMESPACE, o: "json")
 	@data = JSON.parse(@conditions)
	getNodesConditions()

  end; nil
  
  def getNodesConditions()
	 self.data.each do |node|
    		if node['type'].equal? self.networkUnavailable
      			self.networkUnavailable = node['status'] 
    		elsif node['type'].equal? self.memoryPressure
			self.memoryPressure = node['status']
		elsif node['type'].equal? self.diskPressure    
                        self.diskPressure = node['status']
		elsif node['type'].equal? self.pIDPressure 
                        self.pIDPressure = node['status']
		elsif node['type'].equal? self.ready
                        self.ready = node['status']
		end
    	end
  end
end; nil

