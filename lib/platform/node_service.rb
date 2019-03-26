module BushSlicer
  module Platform
    class NodeService < OpenShiftService

      def self.discover(host, env)
        self.new(host, env)
      end

      def initialize(host, env)
        super
        @service = SystemdService.new("kubelet.service", host)
      end

      def config
        @config ||= BushSlicer::Platform::NodeConfig.for(self)
      end
    end
  end
end
