module BushSlicer
  # represents a rule inside a cluster role
  class PolicyRule
    attr_reader :non_resource_urls, :resource_names, :verbs

    # @param spec [Hash] what is present in ClusterRole->rules
    # @param owner [Resource] cluster role containing this rule
    def initialize(spec, owner)
      @owner = owner

      @raw = spec.freeze
      @non_resource_urls = spec["nonResourceURLs"]
      @resource_names = spec["resourceNames"]
      @verbs = spec["verbs"]
    end
  end
end
