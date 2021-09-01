#Functions for Kata tests, kataconfig level

include BushSlicer
require "verification-tests/lib/world"
require "verification-tests/features/kata/test_functions/cluster"
require "verification-tests/features/kata/test_constants"
require "verification-tests/features/kata/objects/node"



def isKataInProgress(namespace: KATA_NAMESPACE, kataconfigName: DEFAULT_KATCONFIG)
#Checking if kata installation is in progress
#namespace: cluster namespace to check in default:'openshift-sandboxed-containers-operator' type: string
#kataconfigName: kataconfig name to check default:"example-kataconfig" type: string
#return: true if kata installation is in progress, false if not type:boolean

	myworld = DefaultWorld.new()
	myworld.project(namespace)
	@admin = myworld.admin
	begin
        	@kataInstallationInprogress = @admin.cli_exec(:get, resource: "kataconfig/#{kataconfigName}", n:namespace, o: "jsonpath='{@.status.installationStatus.IsInProgress}'")[:stdout]
	rescue
		
	end
	if @kataInstallationInprogress.equal? 'true'
		return true
	else
		return false
	end
end


def getKataCompletedNodesLIst(namespace: KATA_NAMESPACE, kataconfigName: "example-kataconfig")
#Getting list nodes, which completes kata installation 
#namespace: cluster namespace to check in default:'openshift-sandboxed-containers-operator' type: string
#kataconfigName: kataconfig name to check default:"example-kataconfig" type: string
#return: list of completed nodes type: array

	myworld = DefaultWorld.new()
        myworld.project(namespace)
	@admin = myworld.admin
	@completedNodesList = []
        @completedNodesListResult = (@admin.cli_exec(:get, resource: "kataconfig/#{kataconfigName}", n:namespace, o: "jsonpath='{@.status.installationStatus.completed.completedNodesList}'")[:stdout]).split(" ")
	@completedNodesListResult.each do |node|
		node = node.delete("'")
		@completedNodesList.push(node)
	end
        return @completedNodesList
end

