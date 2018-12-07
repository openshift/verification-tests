module VerificationTests
  module Platform
    class MasterSystemdService < MasterService
      attr_reader :env

      CHECK_SERVICES = ["atomic-openshift-master", "atomic-openshift-master-api"].freeze
      MANAGED_SERVICES = (CHECK_SERVICES + ["atomic-openshift-master-controllers"]).freeze

      def self.detected_on?(host)
        CHECK_SERVICES.any? { |s| SystemdService.configured?(s, host) }
      end

      def service
        unless @service
          @service = AggregationService.new(
            MANAGED_SERVICES.select { |s| SystemdService.configured?(s, host) }.map{ |s|
              SystemdService.new(s, host, expected_load_time: expected_load_time)
            }
          )
        end
        return @service
      end
    end
  end
end
