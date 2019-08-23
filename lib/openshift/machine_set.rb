require 'openshift/cluster_resource'

module BushSlicer
  # represents MachineSet
  class MachineSet < ProjectResource
    RESOURCE = 'machinesets'
  end
end
