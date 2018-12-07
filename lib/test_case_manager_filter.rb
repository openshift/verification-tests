require 'cucumber/core/filter'

module VerificationTests
  # this class lives throughout the whole test execution
  #  it passes filter events to the Test Case Manager
  #  IMPORTANT: needs to run as last filter in the chain because test case
  #    manager expects to be called at the time a scenario would be run;
  #    other filters will compromise this assumption
  TestCaseManagerFilter = Cucumber::Core::Filter.new(:tc_manager) do
    # called upon new scenario
    def test_case(test_case)
      tc_manager.push(test_case)

      # run each test case that manager returns; it means ready to be executed
      while case_to_run = tc_manager.next # yes, assignment
        tc_manager.signal(:start_case, case_to_run)
        case_to_run.describe_to receiver
        tc_manager.signal(:end_case, case_to_run)
      end
      return self

      # example fiddling with steps
      #activated_steps = test_case.test_steps.map do |test_step|
      #  test_step.with_action { }
      #end
      #test_case.with_steps(activated_steps).describe_to receiver

      # super source at time of writing
      # test_case.describe_to receiver
      # return self
    end

    # called at end of execution to print summary
    def done
      tc_manager.signal(:end_of_cases)

      super
      # super source at time of writing
      # receiver.done
      # return self
    end
  end
end
