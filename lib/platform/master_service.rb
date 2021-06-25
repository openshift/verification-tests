require 'cucuhttp'

module BushSlicer
  module Platform
    # @note this class represents an OpenShift master server that is running
    #   Kubernetes Services like API and Controller
    class MasterService < OpenShiftService
      include Common::Helper

      IMPLEMENTATIONS = [MasterSystemdService, MasterScriptedStaticPodService]

      def self.type(host)
        IMPLEMENTATIONS.find { |i| i.detected_on?(host) }
      end

      def config
        @config ||= BushSlicer::Platform::MasterConfig.for(self)
      end

      private def expected_load_time
        controller_lease_ttl + 5
      end

      private def controller_lease_ttl
        @controller_lease_ttl ||= config.as_hash["controllerLeaseTTL"] || 30
      end

      private def local_api_port
        @local_api_port ||= config.as_hash.dig("servingInfo", "bindAddress").split(":").last
      end

      private def api_url
        @api_url ||= "https://#{host.hostname}:#{local_api_port}"
      end

      private def wait_start(**opts)
        res = {}
        proxy_opt = {}
        proxy_opt[:proxy] = env.client_proxy if env.client_proxy
        success = wait_for(expected_load_time, interval: 5) {
          (res = Http.get(url: api_url, **proxy_opt))[:success]
        }
        if opts[:raise] && !success
          raise "API did not start responding on #{host.hostname}"
        end
        return res
      end

      def start(**opts)
        BushSlicer::ResultHash.aggregate_results([super, wait_start(**opts)])
      end

      def restart(**opts)
        res = super
        # no better idea than hardcoding time needed for node to react on master restart command
        sleep 10
        BushSlicer::ResultHash.aggregate_results([res, wait_start(**opts)])
      end
    end
  end
end
