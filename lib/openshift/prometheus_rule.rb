require 'openshift/project_resource'
require 'openshift/flakes/prometheus_rule_group_spec'

module BushSlicer
  class PrometheusRule < ProjectResource
    RESOURCE = "prometheusrules"

    def groups(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'groups')
    end 

    def prometheus_rule_groups_spec(user: nil, cached: false, quiet: false)
      specs = []
      prometheus_rule_groups_spec = groups(user: user)
      prometheus_rule_groups_spec.each do | prometheus_rule_group_spec |
        specs.push PrometheusRuleGroupSpec.new prometheus_rule_group_spec
      end
      return specs
    end

    # return the spec for a specific group identified by the param name
    def prometheus_rule_group_spec(user: nil, name:, cached: false, quiet: false)
      specs = prometheus_rule_groups_spec(user: user, cached: cached, quiet: quiet)
      target_spec = {}
      specs.each do | spec |
        target_spec = spec if spec.name == name
      end
      raise "No group spec found matching '#{name}'!" if target_spec.is_a? Hash
      return target_spec
    end


  end
end
