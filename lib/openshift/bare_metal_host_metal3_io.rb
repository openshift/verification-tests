require 'openshift/project_resource'

module BushSlicer
  class BareMetalHostMetal3Io < ProjectResource
    RESOURCE = 'baremetalhost.metal3.io'
    def boot_mac_address(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet).dig("spec", "bootMACAddress")
    end
    def machine_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet).dig("spec", "consumerRef", "name")
    end
    def node_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet).dig("status", "hardware", "hostname")
    end
    def provision_status(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet).dig("provisioning","state")
    end

  end
end

