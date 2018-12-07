module VerificationTests
  # represents an OpenShift ConfigMap
  class Bundle < ProjectResource
    RESOURCE = "bundles"

    def runtime(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'runtime')
    end

    def fq_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'fq_name')
    end

    def version(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'version')
    end

  end
end
