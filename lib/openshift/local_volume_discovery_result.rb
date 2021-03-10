require 'openshift/project_resource'
require 'openshift/flakes/discovered_devices'

module BushSlicer
  # represents an OpenShift (pvc for short)
  class LocalVolumeDiscoveryResult < ProjectResource
    RESOURCE="localvolumediscoveryresults.local.storage.openshift.io"

    def discovered_devices(user: nil, quiet: false, cached: true)
      rr = raw_resource(user: user, quiet: quiet, cached: cached).dig('status', 'discoveredDevices')
      rr.map { |d| DiscoveredDevices.new d }
    end

    # @return [Array of `available` DiscoveredDevice]
    def available_devices(user: nil, quiet: false, cached: true)
      devices = discovered_devices(user: user, quiet: quiet, cached: cached)
      devices.select { |d| d.status == 'Available'}
    end
  end
end
