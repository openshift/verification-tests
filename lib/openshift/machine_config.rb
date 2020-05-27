require 'openshift/cluster_resource'

module BushSlicer
  # represents MachineConfig
  class MachineConfig < ClusterResource
    RESOURCE = 'machineconfigs'
  end
end
