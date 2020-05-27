require 'openshift/project_resource'

module BushSlicer
  # represents an OpenShift OperatorSource
  class OperatorSource < ProjectResource
    RESOURCE = "operatorsources"

    def packages(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'packages')
    end

    def finalizers(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('metadata', 'finalizers')
    end
  end
end
