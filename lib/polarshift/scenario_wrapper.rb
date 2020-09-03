# frozen_string_literal: true

module BushSlicer
  module PolarShift
    # wrapper for Cucumber scenarios
    class ScenarioWrapper
      attr_reader :test_case, :attachments
      @@api_checked = false

      # @param test_case [Cucumber::Core::Test::Case]
      def initialize(test_case)
        @test_case = test_case
        @attachments = []
        api_check!
      end

      alias cucumber_test_case test_case

      # this scenario is starting execution
      def start!
        @started_at = Time.now
      end

      # indicates scenario completed execution
      def finish!
        @finished_at = Time.now
      end

      # @param test_case [Cucumber::Core::Test::Case]
      private def matches?(test_case)
        self.location == test_case.location.to_s
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def match!(test_case)
        if matches?(test_case)
          @test_case = test_case if self.class.running_test_case?(test_case)
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
        !error? && self.class.running_test_case?(test_case) && test_case.passed?
      end

      def error?
        @failed_before || @failed_after
      end

      def failed?
        !error? && self.class.running_test_case?(test_case) && test_case.failed?
      end

      def example?
        test_case.keyword == "Scenario Outline"
        # https://github.com/cucumber/cucumber-ruby-core/issues/119
        # test_case.outline?
      end

      def file
        test_case.location.file
      end

      # @return [String] name of this scenario or if this is an example from
      #   an Outline, then the name of the Scenario Outline
      def name
        # btw we can also use #match_name? but this should be faster for us
        example? ? test_case.source[-3].name : test_case.name
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
          outline = test_case.source[-3]
          # outline.examples_tables.reduce(0) { |sum, t| sum + t.example_rows.size }
          outline.examples_tables.map(&:example_rows).map(&:size).reduce(&:+)
        end
      end

      # @return [String] name of the examples table this scenario is part of
      def examples_table_name
        test_case.source[-2].name if example?
      end

      # @return [Integer] number of examples contained in the examples table
      #   this scenario is part of
      def examples_table_size
        test_case.source[-2].example_rows.size if example?
      end

      # @return [Hash] the arguments from the examples table associated with
      #   this example
      def example_args
        test_case.source.last.instance_variable_get(:@data) if example?
      end

      # @param test_case [Cucumber::Core::Test::Case]
      # @return [Boolean] whether this is a running test case or Core test case,
      #   e.g. Cucumber::RunningTestCase::ScenarioOutlineExample
      def self.running_test_case?(test_case)
        test_case.respond_to? :failed?
      end

      private def api_check!
        if !@@api_checked && example?
          if test_case.source.last.class.to_s.end_with?("::Row") &&
              test_case.source[-2].class.to_s =~ /::Examples(Table)?$/ &&
              test_case.source[-3].class.to_s.end_with?("ScenarioOutline")
            @@api_checked = true
          else
            raise "Cucumber API seems to have changed, code here needs update."
          end
        end
      end
    end
  end
end
