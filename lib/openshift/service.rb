require 'yaml'

require 'openshift/project_resource'

require 'openshift/pod'
require 'openshift/route'

module BushSlicer
  # represents OpenShift v3 Service concept
  class Service < ProjectResource
    RESOURCE = "services"

    # @return [BushSlicer::ResultHash] with :success if at least one pod by
    #   selector is ready
    def ready?(user: nil, quiet: false, cached: false)
      res = {}
      pods = pods(user: user, quiet: quiet, cached: cached, result: res)
      pods.select! { |p| p.ready?(user: user, cached: true)[:success] }
      res[:success] = pods.size > 0
      return res
    end

    # @return [Array<Pod>]
    def pods(user: nil, quiet: false, cached: true, result: {})
      if !selector(user: user, quiet: quiet) || selector.empty?
        raise "can't tell if ready for services without pod selector"
      end

      unless cached && props[:pods]
        props[:pods] = Pod.get_labeled(*selector,
                                       user: default_user(user),
                                       project: project,
                                       quiet: quiet,
                                       result: result)
      end
      return props[:pods]
    end

    # @param by [BushSlicer::User] the user to create route with
    def expose(user: nil, port: nil)
      opts = {
        output: :yaml,
        resource: :service,
        resource_name: name,
        namespace: project.name,
      }
      opts[:port] = port if port
      res = default_user(user).cli_exec(:expose, **opts)

      if res[:success]
        res[:parsed] = YAML.load(res[:response])
        route = Route.from_api_object(project, res[:parsed])
        route.service = self
        return route
      else
        raise "could not expose service: #{res[:response]}"
      end
    end

   # @note call without user only when props are loaded; get object to refresh
    def selector(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'selector')
    end

    # @note call without parameters only when props are loaded
    def url(user: nil, cached: true, quiet: false)
      ip = self.ip(user: user, cached: cached, quiet: quiet)
      ip = ip.include?(":") ? "[#{ip}]" : ip
      port = self.ports(user: user, cached: true, quiet: quiet)[0]["port"]
      "#{ip}:#{port}"
    end

    def hostname
      "#{name}.#{project.name}.svc"
    end

    # @note call without parameters only when props are loaded
    def ip(user: nil, cached: true, quiet: false)
      spec = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec')
      return (spec.dig('portalIP') || spec.dig('clusterIP'))
    end
    
    # return service ipv6 address for dualstack cluster
    def ip_v6(user: nil, cached: true, quiet: false)
      spec = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec')
      ipv6 = spec['clusterIPs'].find { |ip| ip.include? ":" }
      return ipv6
    end

    # return service ipv6 address as URL for dualstack cluster
    def ip_v6_url(user: nil, cached: true, quiet: false)
      ipv6 = self.ip_v6(user: user, cached: cached, quiet: quiet)
      port = self.ports(user: user, cached: true, quiet: quiet)[0]["port"]
      "[#{ipv6}]:#{port}"
    end

    # return service ipv4 address for dualstack cluster
    def ip_v4(user: nil, cached: true, quiet: false)
      spec = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec')
      ipv4 = spec['clusterIPs'].find { |ip| ip.include? "." }
      return ipv4
    end

    # return service ipv4 address as URL for dualstack cluster
    def ip_v4_url(user: nil, cached: true, quiet: false)
      ipv4 = self.ip_v4(user: user, cached: cached, quiet: quiet)
      port = self.ports(user: user, cached: true, quiet: quiet)[0]["port"]
      "#{ipv4}:#{port}"
    end

    # @note call without parameters only when props are loaded
    # return @Array of ports
    def ports(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'ports')
    end

    # @note call without parameters only when props are loaded
    def node_port(user: nil, port:, cached: true, quiet: false)
      node_port = nil
      ports = self.ports(user: user, cached: cached, quiet: quiet)
      ports.each do | p |
        node_port = p['nodePort'] if p['port'] == port
      end
      return node_port
    end

    def port(user: nil, name:, cached: true, quiet: false)
      port = nil
      ports = self.ports(user: user, cached: cached, quiet: quiet)
      ports.each do | p |
        port = p['port'] if p['name'] == name
      end
      raise "Could not find port with name #{name}, does the name really exist?" if port.nil?
      return port
    end

    def loadbalancer_ingress(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'loadBalancer', 'ingress')
    end

    # @return [String] string IP if IPv4 or [IP] if IPv6
    def ip_url(user: nil, cached: true, quiet: false)
      raw_ip = ip(user: user, cached: cached, quiet: quiet)
      return raw_ip.include?(":") ? "[#{raw_ip}]" : raw_ip
    end

  end
end
