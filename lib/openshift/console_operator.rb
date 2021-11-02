require 'openshift/cluster_resource'

module BushSlicer
  class ConsoleOperator < ClusterResource
    RESOURCE = 'console.operator'

    def plugins(user: nil, cached: false, quiet: false)
      spec = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec')
      spec.dig('plugins')
    end

    def spec(user: nil, cached: true, quiet: true)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('spec')
    end
  end
end
