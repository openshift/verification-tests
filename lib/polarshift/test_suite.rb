# frozen_string_literal: true

module BushSlicer
  module PolarShift
    class TestSuite
      attr_reader :opts, :request, :test_run
      private :opts, :test_run

      # @param opts [Hash] options like services->polarshift->...
      def initialize(**opts)
        @request = Request.new(opts)
        @opts = request.send(:test_suite_opts)

        init_by_spec(ENV["TCMS_SPEC"] || @opts[:spec])
      end

      def init_by_spec(spec)
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
        request.default_project
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
      # @note unused with Cucumber 5.3 integration
      # def test_case_next!
      #   unless current_test_record
      #     record = pending.find { |test_record| test_record.reserve! }
      #     self.current_test_record = record if record
      #   end

      #   if current_test_record
      #     return current_test_record.next_cucumber_case!
      #   else
      #     return nil
      #   end
      # end

      # reserve a matching test record (unless we already have one) and mark
      #   test scenario as running
      # @param [Cucumber::Core::Test::Case] test_case starting that we need to
      #   commit to or reject
      # @return [Boolean] whether we want to run this test case or not
      # @note #test_case_execute_start! is redundant when test_case_next! is
      #   not used
      def commit!(test_case)
        unless self.current_test_record
          record = pending.find { |test_record| test_record.match! test_case }
          unless record
            raise "logic error: filter shouldn't ask us about test cases not part of the run"
          end
          if record.reserve!
            self.current_test_record = record
          else
            return false
          end
        end

        if self.current_test_record.start_scenario_for! test_case
          return true
        else
          raise "logic error: starting test case that is not part of current test record"
        end
      end

      # @param test_case [Cucumber::Core::Test::Case]
      # @note this method is redundant when using #reserve! instad of
      #   #test_case_execute_start!
      def test_case_execute_start!(test_case)
        test_case_expected?(test_case)
      end

      # @param test_case [Cucumber::Events::TestRunFinished]
      def test_case_execute_finish!(event, attach:)
        unless current_test_record
          raise "Bug in test case management - current test record is not set but we finished scenario '#{event.test_case.name}'"
        end
        test_case_expected?(event.test_case)
        current_test_record.finished!(event, attach: attach)
      ensure
        if current_test_record&.finished?
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

      # @return [Enumerator<Cucumber::Core::Test::Case>] the remaining pending
      #   Cucumber test cases (does not include current test record)
      def all_cucumber_test_cases(randomize: false)
        test_records = pending
        test_records.shuffle! if randomize
        if block_given?
          test_records.each { |record|
            record.test_case.scenarios.each { |scenario_wrapper|
              yield scenario_wrapper.cucumber_test_case
            }
          }
          nil
        else
          Enumerator.new do |tcs|
            test_records.each { |record|
              record.test_case.scenarios.each { |scenario_wrapper|
                tcs << scenario_wrapper.cucumber_test_case
              }
            }
          end
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
