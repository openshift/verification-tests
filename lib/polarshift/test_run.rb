# frozen_string_literal: true

module VerificationTests
  module PolarShift
    class TestRun
      attr_reader :request, :struct

      private :struct

      # @param opts [Hash] options like services->polarshift->...
      def initialize(struct, request)
        @request = request
        @struct = struct

        struct["records"] = struct["records"]["TestRecord"].map do |test_record|
          TestRecord.new test_record, self
        end
      end

      def self.for_cases(case_ids, project, request)
        # When running with cases that usually means changes to the case have
        #   been recently made. This means in most situations we need to
        #   refresh the cases from Polarion to avoid frustration.
        request.refresh_cases_wait(project, case_ids)
        cases = request.get_cases_smart(project, case_ids)
        return self.new({
          "virtual" => true,
          "projectURI" => "subterra:data-service:objects:/default/#{project}${Project}#{project}",
          "records" => {
            "TestRecord" => cases.map{|c| {"test_case" => c}}
          }
        }, request)
      end

      def self.for_run(run_id, project, request)
        hash = request.get_run_smart(project, run_id, with_cases: "automation")
        return self.new(hash, request)
      end

      def project_id
        @project_id ||= struct["projectURI"].split('${Project}').last
      end

      def id
        struct["id"]
      end

      def virtual?
        struct["virtual"]
      end

      def test_records
        struct["records"]
      end
    end
  end
end
