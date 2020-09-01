require 'openshift/project_resource'

module BushSlicer
  class ThanosRuler < ProjectResource
    RESOURCE = "thanosrulers.monitoring.coreos.com"

    def log_level(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig("spec", "logLevel")
    end

  end
end