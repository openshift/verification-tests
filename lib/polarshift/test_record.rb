# frozen_string_literal: true

require 'time'
require_relative 'test_case'

module BushSlicer
  module PolarShift
    class TestRecord
      attr_reader :test_run, :struct

      private :struct

      def initialize(struct, test_run)
        @test_run = test_run
        @struct = struct

        if struct["test_case"]
          struct["test_case"] = TestCase.new(struct["test_case"], request)
        end
      end

      def request
        test_run.request
      end

      def logger
        request.logger
      end

      # @return [PolarShift::TestCase, nil]
      def test_case
        defined?(@test_case) ? @test_case : @test_case = struct["test_case"]
      end

      def project_id
        test_run.project_id
      end

      def run_id
        test_run.id
      end

      def test_case_id
        @test_case_id ||=
          if virtual?
            unless test_case
              raise "virtual test record without test case must be a bug"
            end
            test_case.id
          else
            struct["testCaseURI"].split('${WorkItem}').last
          end
      end
      alias human_id test_case_id

      def test_case_uri
        struct["testCaseURI"]
      end

      def result_status
        struct.dig("result")
      end

      def comment
        struct.dig("comment", "content")
      end

      def comment=(value)
        struct["comment"]["content"] = value
      end

      def executed
        Time.parse(struct["executed"]) rescue nil
      end

      def duration
        Float(struct["duration"]) rescue 0.0
      end

      # @return [Boolean]
      def virtual?
        if defined? @virtual
          @virtual
        else
          @virtual = (struct.keys - ["test_case"]).empty?
        end
      end

      # @return [Boolean]
      def reserve!
        if virtual? || !runnable_status?
          @reserved = true
        else
          success = update_to!({
            "comment" => "reserved by #{EXECUTOR_NAME} #{rand(100000)}",
            "result" => "Running",
            "duration" => duration,
            "executed" => executed || Time.now.utc.iso8601
          })

          @reserved = true if success

          return success
        end
      end

      def invalidate!
        @outdated = true
      end

      # @param test_case [Cucumber::Core::Test::Case]
      # @return [Boolean] whether Cucumber scenario is matching this record
      def match!(test_case)
        self.test_case && self.test_case.match!(test_case)
      end

      # @return [Boolean] whether update succeeded
      # @raise on unknown errors
      def update_to!(new_state)
        raise "cannot update virtual test record" if virtual?
        logger.info "Updating PolarShift test case #{test_case_id} with #{new_state["result"]} status and duration of #{new_state["duration"]} seconds"
        res = request.update_caseruns(project_id, run_id, {
          "id" => test_case_id,
          "current" => {
            "comment" => comment,
            "result" => result_status,
          },
          "new" => new_state
        })

        if res[:success]
          if new_state["comment"]
            new_state = new_state.dup
            self.comment = new_state.delete("comment")
          end
          struct.merge! new_state
          return true
        elsif res[:exitstatus] == 409
          # record changed since we last saw its status
          invalidate!
          return false
        else
          logger.error(res[:response])
          raise res[:error]
        end
      end

      # @return [Cucumber::Core::Test::Case]
      # @note redundant with Cucumber 5.3 integration
      # def next_cucumber_case!
      #   unless complete?
      #     raise "inconsistent logic: we didn't yet see (all) scenarios for the test case but next scenario is requested"
      #   end

      #   unless reserved?
      #     raise "inconsistent logic: we didn't reserve case but next scenario is requested"
      #   end

      #   if self.test_case.scenarios.any? { |s| s.in_progress? }
      #     raise "inconsistent logic: we have a scenario in progress but next is requested"
      #   end

      #   scenario = test_case.scenarios.find{ |s| s.pending? }
      #   unless scenario
      #     raise "inconsistent logic: no pending scenario but we were asked to start one"
      #   end
      #   scenario.start!
      #   return scenario.cucumber_test_case
      # end

      # @param test_case [Cucumber::Core::Test::Case] test_case that is started
      # @return [Boolean]
      def start_scenario_for!(test_case)
        scenario = self.test_case.scenarios.find { |s| s.match! test_case}
        unless scenario
          logger.warn "logic error"
          logger.warn "trying to start Cucumber scenario for test case #{test_case}: #{test_case.name}"
          logger.warn "but we are using test record from: #{self.test_case.scenarios.first.name}"
          return false
        else
          scenario.start!
          return true
        end
      end

      # @param test_case [Cucumber::Core::Test::Case, Cucumber::Events::TestRunFinished]
      # @return [ScenarioWrapper]
      def current_scenario_for(test_case)
        scenarios = self.test_case.scenarios.select { |s| s.in_progress? }
        if scenarios.size != 1
          raise "expected only one running scenario for #{test_case_id} but we have #{scenarios.size}"
        end
        scenario = scenarios.first

        unless scenario.match! test_case
          raise "expected to have current running scenario match the test case #{test_case} but it does not"
        end

        return scenario
      end

      # @param event [Cucumber::Events::TestCaseFinished]
      # @param attach [Array<String>] URLs to put in comment
      def finished!(event, attach: [])
        scenario = current_scenario_for(event)
        scenario.finish!
        scenario.attach(attach)

        # TODO: should we skip any other scenarios from current test case if
        #  this scenario failed or errored?

        if !virtual? && finished?
          attachments = self.test_case.scenarios.map(&:attachments).reduce(&:+).join("\n")
          # for internal datahub URL, the polarshift-ui method 'formatLinks'
          # doesn't create the hyperlink correctly, so it here to get
          # around... kind of hacky.
          if attachments.include? "/url/generate?key"
            attachments = "<a href='#{attachments}', target='_blank'>presigned_url</a>"
          end
          success = update_to!({
            "comment" => %{executed by #{EXECUTOR_NAME}\n#{attachments}},
            "result" => self.test_case.result,
            "duration" => duration +
                          self.test_case.scenarios.map(&:duration).reduce(&:+),
            "executed" => executed || Time.now.utc.iso8601
          })

          unless success
            raise "something changed test record while we've been working hard"
          end
        end
      end

      # @return [Boolean] whether we have executed all defined scenarios
      def finished?
        # once we finish, return quickly true
        @finished ||= automated? && !test_case.scenarios.empty? &&
          test_case.scenarios.all? {|s| s.finished?}
      end

      def automated?
        test_case.automated?
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def before_hook_failed!(test_case)
        current_scenario_for(test_case).failed_before!
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def after_hook_failed!(test_case)
        current_scenario_for(test_case).failed_after!
      end

      # @param test_case [Cucumber::Core::Test::Case] check if cucumber
      #   scenario is in progress; if nil checks whether we are in_progress
      def in_progress?(test_case)
        if test_case
          !!current_scenario_for(test_case) rescue false
        else
          reserved? && !finished?
        end
      end

      # @return [Boolean] whether case for this record has been executed by us;
      #   that means this object went through test execution workflow at least
      #   partially
      def executed?
        reserved?
      end

      # @return [Boolean] whether we've seen all cucumber test cases defined
      #   in PolarShift test case
      def complete?
        test_case.complete?
      end

      def reserved?
        @reserved
      end

      # @return [Boolean] do we know for sure that current struct is outdated
      def outdated?
        @outdated
      end

      # @return [Boolean] whether we have everything needed to execute
      def pending?
        if test_case&.scenarios&.any? { |s| s.name == "Container could reach the dns server"}
          # require 'pry'; binding.pry
        end
        runnable? && complete?
      end

      # @return [Boolean] whether record result would allow us to execute
      def runnable_status?
        virtual? && !finished? ||
          !outdated? && ["Waiting", "Rerun"].include?(result_status)
      end

      # @return [Boolean] whether record result and other metadata allow us to
      #   execute
      def runnable?
        test_case && runnable_status? && complete?
      end
    end
  end
end
