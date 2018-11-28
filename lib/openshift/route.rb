require 'common'
require 'openshift/project_resource'

module BushSlicer
  # @note represents an OpenShift route to a service
  #   https://docs.openshift.com/enterprise/3.0/architecture/core_concepts/routes.html
  class Route < ProjectResource
    RESOURCE = "routes"

    attr_reader :props, :name
    attr_writer :service

    # @param name [String] name of route
    # @param service [BushSlicer::Service] the service exposed via this route
    # @param props [Hash] additional properties of the route
    # @note custom constructor for historical reasons but should be compatible
    #   with ProjectResource@initialize
    def initialize(name: nil, project: nil, service: nil)
      if service
        @name = name || service.name
        @service = service
        super(name: name, project: service.project)
      elsif project
        super(name: name, project: project)
      else
        raise "project or service must be provided here"
      end
    end

    def http_get(by:, proto: "http", port: nil, **http_opts)
      portstr = port ? ":#{port}" : ""
      BushSlicer::Http.get(url: proto + "://" + dns(by: by) + portstr,
                          **http_opts)
    end

    def wait_http_accessible(by:, proto: "http", port: nil,
                             timeout: nil, **http_opts)
      # TODO: are there non-http routes? we may try to auto-sense the proto
      res = nil
      timeout ||= 15*60

      iterations = 0
      start_time = monotonic_seconds

      wait_for(timeout) {
        res = http_get(by: by, proto: proto, port: port, quiet: true,
                       **http_opts)

        logger.info res[:instruction] if iterations == 0
        iterations = iterations + 1

        if SocketError === res[:error] &&
            res[:error].to_s.include?('getaddrinfo')
          # unlikely to ever succeed when we can't resolve domain name
          break
        end
        res[:success]
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        " seconds:\n#{res[:response]}"

      return res
    end

    # load route props from a Route OpenShift API object
    #   apiVersion: v1
    #   kind: Route
    #   metadata:
    #     annotations:
    #       openshift.io/host.generated: "true"
    #     creationTimestamp: 2015-07-27T15:24:58Z
    #     name: myapp
    #     namespace: xaxa
    #     resourceVersion: "52293"
    #     selfLink: /osapi/v1beta3/namespaces/xaxa/routes/myapp
    #     uid: a454f9db-3473-11e5-a56e-fa163eee310a
    #   spec:
    #     host: myapp.xaxa.cloudapps.example.com
    #     to:
    #       kind: Service
    #       name: myapp
    #   status: {}

    def service(user: nil, quiet: true)
      return @service if defined?(@service)

      if for_service?(user: user, cached: true, quiet: true)
        service_name = raw_resource(user: user, cached: true, quiet: quiet).
          dig("spec", "to", "name")
        @service = Service.new(name: service_name, project: project)
        @service.default_user = default_user(user)
        return @service
      end
    end

    def for_service?(user: nil, cached: true, quiet: true)
      "Service" == raw_resource(user: user, cached: cached, quiet: quiet)
                                                    .dig("spec", "to", "kind")
    end

    # @param by [User] kept for backward compatibility only
    def dns(by: nil, user: nil, cached: true, quiet: false)
      user ||= by
      return raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "host")
    end
    # check for ingress route only
    def ready?(user: nil, quiet: false)
      status = raw_resource(user: user, cached: false, quiet: quiet)['status']
      ready = status.dig('ingress').last['conditions'].any? do |con|
        con['type'] == "Admitted" && con['status'] == "True"
      end
      return ready
    end
  end
end
