require 'openshift/project_resource'
require 'openshift/flakes/service_monitor_endpoint_spec'

module BushSlicer
  class ServiceMonitor < ProjectResource
    RESOURCE = "servicemonitors"

    private def endpoints(user: nil, quiet: false, cached: true)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'endpoints')
    end

    def service_monitor_endpoints_spec(user: nil, cached: true, quiet: false)
      specs = []
      service_monitor_endpoints_spec = endpoints(user: user)
      service_monitor_endpoints_spec.each do | service_monitor_endpoint_spec |
        specs.push ServiceMonitorEndpointSpec.new service_monitor_endpoint_spec
      end
      return specs
    end

    # return the spec for a specific endpoint identified by the param port
    def service_monitor_endpoint_spec(user: nil, port:, cached: true, quiet: false)
      specs = service_monitor_endpoints_spec(user: user, cached: cached, quiet: quiet)
      target_spec = {}
      specs.each do | spec |
        target_spec = spec if spec.port == port
      end
      raise "No endpoint spec found matching '#{port}'!" if target_spec.is_a? Hash
      return target_spec
    end

  end
end
