require 'openshift/cluster_resource'
require 'openshift/flakes/machine_config_pool_spec'
module BushSlicer
  # represents MachineConfigPool
  class MachineConfigPool < ClusterResource
    RESOURCE = 'machineconfigpools'
    def spec(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet).dig("spec")
      MachineConfigPoolSpec.new rr
    end
  end
end
