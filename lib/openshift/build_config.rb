require 'openshift/project_resource'

require 'openshift/flakes/build_config_trigger'
require 'openshift/flakes/build_strategy'

module VerificationTests
  # represents an OpenShift build
  class BuildConfig < ProjectResource
    RESOURCE = "buildconfigs"

    def output_to_ref(user: nil, cached: true, quiet: false)
      unless cached && props[:output_to_ref]
        raw = raw_resource(user: user, cached: cached, quiet: quiet)
        spec = raw.dig("spec", "output", "to")
        props[:output_to_ref] = ObjectReference.new(spec)
      end
      return props[:output_to_ref]
    end

    def output_to(user: nil, cached: true, quiet: false)
      output_to_ref(user: user, cached: cached, quiet: quiet).resource(self)
    end

    def strategy(user: nil, cached: true, quiet: false)
      unless cached && props[:strategy]
        raw = raw_resource(user: user, cached: cached, quiet: quiet)
        spec = raw.dig("spec", "strategy")
        props[:strategy] = BuildStrategy.from_spec(spec, self)
      end
      return props[:strategy]
    end

    # @return [Array<BuildConfigTrigger>]
    def triggers(user: nil, cached: true, quiet: false)
      unless cached && props[:triggers]
        triggers = raw_resource(user: user, cached: cached, quiet: quiet).
          dig("spec", "triggers") || []
        props[:triggers] = BuildConfigTrigger.from_list(triggers, self)
      end
      return props[:triggers]
    end

    # return trigger params matched by type
    def trigger_by_type(user: nil, type:, cached: true, quiet: false)
      triggers = self.triggers(user: user, cached: cached, quiet: quiet)
      triggers = triggers.select {|t| t.type == type}
      if triggers.size == 1
        return triggers[0]
      elsif triggers.size == 0
        raise "no #{type} triggers found for BC #{name}"
      else
        raise "confusing, found #{triggers.size} #{type} triggers for BC " \
          "#{name}, use some better method to select"
      end
    end
  end
end
