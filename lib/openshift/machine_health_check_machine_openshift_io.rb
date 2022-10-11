require 'openshift/project_resource'

module BushSlicer
  # represents MachineHealthCheck
  class MachineHealthCheckMachineOpenshiftIo < ProjectResource
    RESOURCE = 'machinehealthchecks.machine.openshift.io'
  end
end

