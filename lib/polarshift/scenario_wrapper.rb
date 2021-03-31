# frozen_string_literal: true

module BushSlicer
  module PolarShift
    # wrapper for Cucumber scenarios
    class ScenarioWrapper
      attr_reader :test_case, :attachments, :result
      @@api_checked = false

      private :result

      # @param test_case [Cucumber::Core::Test::Case]
      def initialize(test_case)
        @test_case = test_case
        @attachments = []
      end

      alias cucumber_test_case test_case

      # this scenario is starting execution
      def start!
        if @started_at
          raise "logic error: trying to start scenario twice: #{name}"
        end
        @started_at = Time.now
      end

      # indicates scenario completed execution
      def finish!
        @finished_at = Time.now
      end

      private def source
        @source ||= Manager.instance.ast_lookup.scenario_source(test_case)
      end

      # @return [Cucumber::Messages::GherkinDocument::Feature::TableRow]
      private def example
        source.row if source.respond_to? :scenario_outline
      end

      # @return [Cucumber::Messages::GherkinDocument::Feature::Scenario::Examples] examples table this scenario is part of
      private def examples_table
        unless defined?(@examples_table)
          if example?
            @examples_table = gherkin.examples.find { |table|
              table.table_body.include? example
            }
            unless @examples_table
              raise "Cannot find Examples table we are part of. Cucumber got updated and API is incompatible?"
            end
          else
            @examples_table = nil
          end
        end
        @examples_table
      end

      # @return [Cucumber::Messages::GherkinDocument::Feature::Scenario] the parsed Gherkin of the Scenario (Outline)
      private def gherkin
        source.respond_to?(:scenario_outline) ? source.scenario_outline : source.scenario
      end

      # @param test_case [Cucumber::Core::Test::Case]
      private def matches?(test_case)
        self.location == test_case.location.to_s
      end

      # @param test_case [Cucumber::Core::Test::Case, Cucumber::Events::TestRunFinished]
      def match!(test_case)
        if Cucumber::Events::TestCaseFinished === test_case
          result = test_case.result
          test_case = test_case.test_case
        end
        unless Cucumber::Core::Test::Case === test_case
          raise ArgumentError, "test case should be of type Cucumber::Core::Test::Case but it is #{test_case.inspect}"
        end
        if matches?(test_case)
          @result = result if test_case
          return true
        else
          return false
        end
      end

      # scenario not started execution yet
      def pending?
        !@started_at
      end

      def in_progress?
        !!@started_at && !@finished_at
      end

      def finished?
        !!@finished_at
      end

      def failed_before!
        @failed_before = true
      end

      def failed_after!
        @failed_after = true
      end

      def passed?
        # I don't think we can work with retries but lets keep an eye on it
        # see Cucumber::Core::Test::Result::TYPES for available statuses
        !error? && [:passed, :flaky].include?(result&.to_sym)
      end

      def failed?
        !error? && result&.failed?
      end

      def error?
        @failed_before || @failed_after
      end

      def example?
        !!example
      end

      def file
        test_case.location.file
      end

      # @return [String] name of this scenario or if this is an example from
      #   an Outline, then the name of the Scenario Outline
      def name
        # btw we can also use #match_name? but this should be faster for us
        test_case.name
      end

      def location
        test_case.location.to_s
      end

      # @param attachments [Array] whatever type of attachments underlying
      #   test case manager passes to us, we just store them for later
      def attach(attachments)
        self.attachments.concat attachments
      end

      def duration
        if @started_at && @finished_at
          @finished_at - @started_at
        end
      end

      # @return [Integer] number of examples contained in the whole Outline
      def examples_size
        if example?
          gherkin.examples.map(&:table_body).map(&:size).reduce(&:+)
        end
      end

      # @return [String] name of the examples table this scenario is part of
      def examples_table_name
        examples_table&.name
      end

      # @return [Integer] number of examples contained in the examples table
      #   this scenario is part of
      def examples_table_size
        examples_table&.table_body&.size
      end

      # @return [Hash] the arguments from the examples table associated with
      #   this example
      def example_args
        if example? && !@example_args
          row_array = source.row.cells.map(&:value)
          header = examples_table.table_header.cells.map(&:value)
          @example_args = Hash[header.zip(row_array)]
        end
        @example_args
      end
    end
  end
end
