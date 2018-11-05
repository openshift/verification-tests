module BushSlicer
  module Platform
    class OpenShiftService
      attr_reader :service, :host, :env
      private :service

      # @param host [Host]
      # @param env [Environment]
      def initialize(host, env)
        @host = host
        @env = env
      end

      def start(**opts)
        service.start(**opts)
      end

      def stop(**opts)
        service.stop(**opts)
      end

      def restart(**opts)
        service.restart(**opts)
      end
    end
  end
end
