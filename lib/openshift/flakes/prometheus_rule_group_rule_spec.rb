require 'base_helper'

module BushSlicer
  class PrometheusRuleGroupRuleSpec
    include Common::Helper

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    def alert
      return struct['alert']
    end

    def annotations
      return struct['annotations']
    end

    def message
      return self.annotations.dig('message')
    end

    def summary
      return self.annotations.dig('summary')
    end

    def expr
      return struct['expr']
    end

    def for
      return struct['for']
    end

    def labels
      return struct['labels']
    end

    def severity
      return self.labels.dig('severity')
    end

    def service
      return self.labels.dig('service')
    end

    def record
      return struct['record']
    end

  end
end
