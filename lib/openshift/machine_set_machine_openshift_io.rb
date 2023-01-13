require 'openshift/project_resource'

module BushSlicer
  # represents MachineSet
  class MachineSetMachineOpenshiftIo < ProjectResource
    RESOURCE = 'machinesets.machine.openshift.io'

    def desired_replicas(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'replicas').to_i
    end

    def available_replicas(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'availableReplicas').to_i
    end

    def ready?(user: nil, quiet: false)
      result = {}
      status = raw_resource(user: user, cached: false, quiet: quiet)['status']
      result[:success] = ([status['availableReplicas'], status['readyReplicas'], status['fullyLabeledReplicas'], status['replicas']].uniq.length == 1)
      return result
    end

    def machines(user: nil, cached: true, quiet: true)
      unless cached && props[:machines]
        user ||= default_user(user)
        all_machines = MachineMachineOpenshiftIo.list(user: user, project: project, get_opts: [[:_quiet, quiet]])
        props[:machines] = all_machines.select {|m| m.machine_set_name == name}
      end
      return props[:machines]
    end

    def cluster(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'selector', 'matchLabels', 'machine.openshift.io/cluster-api-cluster')
    end

    def taints(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('spec', 'taints')
    end

    def is_windows_machinesets?(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'template', 'metadata', 'labels','machine.openshift.io/os-id') == "Windows"
    end 
    def machineset_flavor(user: nil, cached: true, quiet: true)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      ms_provider_spec = rr.dig('spec', 'template', 'spec', 'providerSpec', 'value')
      flavor = ms_provider_spec['instanceType'] || ms_provider_spec['vmSize'] || ms_provider_spec['machineType'] || ms_provider_spec['flavor']
      return flavor
    end

    def aws_machineset_subnet(user: nil, cached: true, quiet: true)
      raw_resource(user: user, cached: cached ,quiet: quiet).
      dig('spec', 'template', 'spec', 'providerSpec', 'value', 'subnet','filters')
    end

    def aws_machineset_subnet_proxy(user: nil, cached: true, quiet: true)
      raw_resource(user: user, cached: cached ,quiet: quiet).
      dig('spec', 'template', 'spec', 'providerSpec', 'value', 'subnet','id')
    end


    def aws_machineset_ami_id(user: nil, cached: true, quiet: false)
       raw_resource(user: user, cached: cached ,quiet: quiet).
         dig('spec', 'template', 'spec', 'providerSpec', 'value', 'ami','id')
    end

    def aws_machineset_availability_zone(user: nil, cached: true, quiet: false)
       raw_resource(user: user, cached: cached ,quiet: quiet).
         dig('spec', 'template', 'spec', 'providerSpec', 'value', 'placement','availabilityZone')
    end

    def aws_machineset_iamInstanceProfile(user: nil, cached: true, quiet: false)
       raw_resource(user: user, cached: cached ,quiet: quiet).
         dig('spec', 'template', 'spec', 'providerSpec', 'value', 'iamInstanceProfile', 'id')
    end

    def aws_machineset_secgrp(user: nil, cached: true, quiet: true)
      raw_resource(user: user, cached: cached ,quiet: quiet).
      dig('spec', 'template', 'spec', 'providerSpec', 'value', 'securityGroups')
    end

  end
end
