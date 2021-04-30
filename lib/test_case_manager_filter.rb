require 'cucumber/core/filter'

module BushSlicer
  # This is a cooperation effort between this class, CucuFormatter,
  #  env.rb (Before/After), TestCaseManager and Manager.
  #  It is likely that this can be simplified now with 5.3 events functionality
  #  but I'm leaving it with as little modifications as possible as initial
  #  migration to avoid ordering and other unexpected issues.
  #
  # In the past (2.4.0) this class lived throughout the whole test execution
  #  and passed filter events to the Test Case Manager. It was a blocking
  #  operation and filter needed to be last. Test case manager expected
  #  to be called at the time a scenario would be run. Now it is not blocking
  #  and we build the scenario/case mapping, then skip scenarios in events.
  class TestCaseManagerFilter < Cucumber::Core::Filter.new(:tc_manager)
    # Each test case is given here for filtering based on name and location.
    # lets fill-in case/scenario mapping and use events to skip test cases.
    # @note this method runs after the :test_case_created hook
    def test_case(test_case)
      # to see what you can do here, you can try
      # show-source Cucumber::Core::Filter

      tc_manager.push(test_case)
      return self
    end

    # called at end of the list to print summary
    def done
      # note that registering events in #initialize results in dup registration
      manager = Manager.instance
      config = manager.cucumber_config

      config.on_event :test_case_started do |event|
        if tc_manager.commit!(event.test_case)
          tc_manager.signal(:start_case, event.test_case)
        else
          # ugly but I don't see another way to mark this test case for skipping
          manager.skip_scenario! event.test_case
        end
      end

      config.on_event :test_case_finished do |event|
        unless event.result.skipped?
          tc_manager.signal(:end_case, event)
        end
      end

      config.on_event :test_run_finished do |event|
        tc_manager.signal(:end_of_cases)
      end

      tc_manager.all_cucumber_test_cases(randomize: true) { |tc|
        tc.describe_to receiver
      }
      super
    end
  end
end
