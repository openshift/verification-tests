class NodeObj
#Class for node object
  include BushSlicer
  require "verification-tests/lib/world"
  require "verification-tests/lib/log"
  require "verification-tests/features/kata/test_functions/cluster"
  require "verification-tests/features/kata/test_constants"
  require 'net/http'
  require 'json'
  attr_reader :name
  attr_accessor :name, :uid, :labels, :networkUnavailable, :memoryPressure, :diskPressure, :pIDPressure, :ready, :conditions, :datajs, :data

  def initialize(name)
#myworld: cucushift default class type:bushslicer default class object
#logger: cucushift logs class type:bushslicer default log class object
#admin: cli class type: bushslicer default cli class object
#uid: node UDI type: string
#labels: node labels type: array
#networkUnavailable: network node status type: string
#memoryPressure: memory node status type: string
#diskPressure: memory node status type: string
#pIDPressure: memory node status type: string
#ready: overall node health status type: string
#data: data dictionary for node conditions type: json
        myworld = DefaultWorld.new()
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
 	@data = JSON.parse(@conditions)
	getNodesConditions()

  end; nil
  
  def getNodesConditions()
#Collecting conditions for node object
#parameter: none
#return: none
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

