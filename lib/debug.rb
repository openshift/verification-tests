module VerificationTests

  # @note contain some debugging related code
  module Debug
    def self.step_fail_cucumber2
      # TODO: override Cucumber::RbSupport::RbStepDefinition.invoke or maybe
      #       even better override World.instance_exec
    end
  end
end
