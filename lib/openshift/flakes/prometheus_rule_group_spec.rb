require 'base_helper'
require 'openshift/flakes/prometheus_rule_group_rule_spec'

module BushSlicer
  class PrometheusRuleGroupSpec
    include Common::Helper

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    def name
      return struct['name']
    end

    def rules 
      return struct['rules']
    end

    def rules_spec
        specs = []
        rules_spec = rules
        rules_spec.each do | rule_spec |
          specs.push PrometheusRuleGroupRuleSpec.new rule_spec
        end
        return specs
      end
  
    # return the spec for a specific rule identified by the param alert
    def rule_spec(alert:, user: nil)
        specs = rules_spec
        target_spec = {}
        specs.each do | spec |
            target_spec = spec if spec.alert == alert
        end
        raise "No rule spec found matching '#{alert}'!" if target_spec.is_a? Hash
        return target_spec
    end

  end
end
