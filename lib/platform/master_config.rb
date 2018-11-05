module BushSlicer
  module Platform
    class MasterConfig
      def self.for(service)
        SimpleServiceYAMLConfig.new(
          service,
          "/etc/origin/master/master-config.yaml"
        )
      end
    end
  end
end
