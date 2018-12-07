# frozen_string_literal: true

module VerificationTests
  module PolarShift
    class TestSuite
      attr_reader :opts, :request, :test_run
      private :opts, :test_run

      # @param opts [Hash] options like services->polarshift->...
      def initialize(**opts)
        @request = Request.new(opts)
        @opts = request.send(:opts)

        init_by_spec
      end

      def init_by_spec
        spec = ENV["TCMS_SPEC"] || opts[:spec]
        if spec.nil? || spec.empty?
          raise "don't know what to execute, please specify TCMS execution specification in TCMS_SPEC"
        end

        type, items = spec.split(':', 2)
        items = items.split(',').map(&:strip)

        case type
        when "case", "cases"
          raise "specify at least one test case" unless items.size > 0
          validate_std_ids items
          @test_run = TestRun.for_cases(items, project_id, request)
        when "run"
          raise "we support only a single test run" unless items.size == 1
          validate_run_ids items
          @test_run = TestRun.for_run(items.first, project_id, request)
        else
          raise "don't know how to handle test cases spec '#{type}'"
        end
      end

      def project_id
        opts[:manager][:project]
      end

      def artifacts_format
        virtual? ? nil : :urls
      end

      def virtual?
        test_run.virtual?
      end

      def validate_std_ids(ids)
        ids.each do |id|
          unless id =~ /\A[-a-zA-Z0-9]+\z/
            raise("parameter #{id} should match /\\A[-a-zA-Z0-9]+\\z/")
          end
        end
      end

      def validate_run_ids(ids)
        ids.each do |id|
          re = /\A[-a-zA-Z0-9 _]+\z/
          unless id =~ re
            raise("parameter #{id} should match #{re}")
          end
        end
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def test_case_push(test_case)
        test_run.test_records.any? {|tr| tr.match!(test_case)}
      end

      # @return [Cucumber::Core::Test::Case, nil]
      def test_case_next!
        unless current_test_record
          record = pending.find { |test_record| test_record.reserve! }
          self.current_test_record = record if record
        end

        if current_test_record
          return current_test_record.next_cucumber_case!
        else
          return nil
        end
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def test_case_execute_start!(test_case)
        test_case_expected?(test_case)
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def test_case_result!(test_case)
        test_case_expected?(test_case)
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def test_case_execute_finish!(test_case, attach:)
        test_case_expected?(test_case)
        current_test_record.finished!(test_case, attach: attach)
      ensure
        if current_test_record.finished?
          self.current_test_record = nil
        end
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def test_case_failed_before!(test_case)
        test_case_expected?(test_case)
        current_test_record.before_hook_failed!(test_case)
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def test_case_failed_after!(test_case)
        test_case_expected?(test_case)
        current_test_record.after_hook_failed!(test_case)
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def test_case_expected?(test_case)
        unless current_test_record
         raise "logic error: expected to have current test record but we do not"
        end

        unless current_test_record.in_progress?(test_case)
          raise "logic error: test case in progress status confusion"
        end
      end

      # @return [PolarShift::TestCase, nil]
      def current_test_record
        @current_test_record
      end

      # for logic validation reasons, allow changes only from nil to non-nil
      #   and vice versa
      # @param value [PolarShift::TestCase]
      def current_test_record=(value)
        if @current_test_record.nil? && value ||
            @current_test_record && value.nil?
          @current_test_record = value
        elsif @current_test_record
          raise "current test record not cleared before setting new one"
        else
          raise "unsetting current test record while it is already unset"
        end
      end

      # are all test cases from spec executed?
      def incomplete?
        test_run.test_records.any? { |test_record| !test_record.executed? }
      end

      # cases without (all) defined scenarios passed to us by cucumber
      def incomplete
        test_run.test_records.select { |test_record|
          test_record.automated? && !test_record.complete? &&
            test_record.runnable_status?
        }
      end

      def executed
        test_run.test_records.select { |test_record| test_record.executed? }
      end

      # already exeuted by others
      def disowned
        test_run.test_records.select { |test_record|
          test_record.automated? &&
            !test_record.reserved? &&
            !test_record.runnable_status?
        }
      end

      # cases without proper automation status or automation-script
      def non_runnable
        test_run.test_records.reject { |test_record| test_record.automated? }
      end

      # scenarios passed from cucumber but not yet executed
      def pending
        test_run.test_records.select { |test_record| test_record.pending? }
      end
    end
  end
end
