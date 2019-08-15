require 'openshift/cluster_resource'

module BushSlicer
  # represents MachineSet
  class MachineSet < ClusterResource
    RESOURCE = 'machineset'
  end
end
