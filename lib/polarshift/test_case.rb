# frozen_string_literal: true

require_relative 'scenario_wrapper'

module BushSlicer
  module PolarShift
    class TestCase
      attr_reader :request, :scenarios, :struct

      private :struct

      def initialize(struct, request)
        @request = request
        @struct = struct
        @scenarios = [] if automated?
      end

      def id
        struct["id"]
      end

      private def custom_fields
        return @custom_fields if @custom_fields
        @custom_fields = {}
        fields = struct.dig("customFields", "Custom") || []
        fields.each { |f| @custom_fields[f["key"]] = f["value"] }
        return @custom_fields
      end

      private def case_automation
        custom_fields.dig("caseautomation", "id")
      end

      def automation_script_raw
        custom_fields.dig("automation_script", "content")
      end

      private def automation_script_parsed
        @automation_script ||=
          begin
            parsed = YAML.load(automation_script_raw)
            Hash === parsed ? parsed : {"raw" => automation_script_raw}
          rescue
            # reached on parse error
            {"raw" => automation_script_raw}
          end
      end

      # private def automation_script
      #   automation_script_parsed["cucushift"]
      # end

      private def automation_file
        return @file if defined?(@file)

        @file = automation_script_parsed.dig("cucushift", "file")
        if @file && !@file.start_with?("features/", "private/")
          @file = "features/#{@file}"
        end
        return @file
      end

      private def automation_scenario
        @automation_scenario ||= "#{automation_script_parsed.dig("cucushift", "scenario")}#{opts[:name_suffix]}"
      end

      private def automation_args
        @automation_args ||=
          automation_script_parsed.dig("cucushift", "args")
      end

      private def tags_raw
        custom_fields["tags"]
      end

      def tags
        tags_raw ? tags_raw.split(/\s+/).reject(&:nil?).reject(&:empty?) : []
      end

      def automated?
        @automated ||=
          case_automation == "automated" &&
          automation_file &&
          automation_scenario &&
          (automation_args.nil? || Hash === automation_args)
      end

      # overal scenario execution result
      def result
        case
        when scenarios.any? { |s| s.error? }
          "Blocked"
        when scenarios.any? { |s| s.failed? }
          "Failed"
        when scenarios.any? { |s| s.pending? || s.in_progress? }
          "Running"
        when scenarios.all? { |s| s.passed? }
          "Passed"
        else
          "Waiting"
        end
      end

      def complete?
        @complete
      end

      private def complete=(value)
        @complete = value
      end

      # check if Cucumber scenario is part of this test case
      # @param test_case [Cucumber::Core::Test::Case]
      # @return [Boolean] whether Cucumber scenario is matching this record
      # @note the difference with #match! is that this method only checks
      #   for already matched Cucumber test cases as well internal state of
      #   ScenarioWrapper objects would not be updated with the matched
      #   test case; useful at scenario execution finish when we only see
      #   outdated test_case object
      # hmm, we don't need such method for the time being

      # @param test_case [Cucumber::Core::Test::Case, Cucumber::Events::TestRunFinished]
      # @return [Boolean] whether Cucumber scenario is matching this record
      def match!(test_case)
        if !automated?
          return false
        elsif scenarios.any? { |s| s.match! test_case }
          return true
        elsif complete?
          return false # no need for expensive checks once we are complete
        else
          scenario = ScenarioWrapper.new(test_case)
          if File.absolute_path(scenario.file) == File.join(BushSlicer::HOME, automation_file) &&
             automation_scenario == scenario.name
            if automation_args && !scenario.example?
              logger.error "case #{id} mismatch with scenario type, will never run"
              return false
            elsif !scenario.example?
              scenarios << scenario
              self.complete = true
              return true
            elsif automation_args.nil? || automation_args.empty?
              # we want the full outline and name already matched
              scenarios << scenario
              self.complete = scenarios.size == scenario.examples_size
              return true
            elsif automation_args["Examples"]
              # we want a full examples table
              if scenario.examples_table_name == automation_args["Examples"]
                scenarios << scenario
                self.complete = scenarios.size == scenario.examples_table_size
                return true
              else
                return false
              end
            elsif scenario.example_args == automation_args
              # we want a single example from an outline
              scenarios << scenario
              self.complete = true
              return true
            else
              return false
            end
          else
            return false
          end
        end
      end

      def logger
        request.logger
      end

      def opts
        @opts ||= request.send(:test_case_opts)
      end
    end
  end
end
