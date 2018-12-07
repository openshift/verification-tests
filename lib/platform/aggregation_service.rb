module VerificationTests
  module Platform
    class AggregationService
      attr_reader :services
      private :services

      # @param services [Object] that has start, stop and possibly restart methods
      def initialize(services)
        @services = services.freeze
      end

      def start(**opts)
        VerificationTests::ResultHash.aggregate_results(services.map(&:start))
      end

      def stop(**opts)
        VerificationTests::ResultHash.aggregate_results(services.reverse_each.map(&:stop))
      end

      def restart(**opts)
        VerificationTests::ResultHash.aggregate_results services.map { |s|
          if s.respond_to? :restart
            s.restart
          else
            VerificationTests::ResultHash.aggregate_results([s.stop, s.start])
          end
        }
      end
    end
  end
end
