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

    def machineconfig(mc_name, user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'configuration', 'source')
      rr.select { |c| c["name"] == mc_name }
    end
  end
end
