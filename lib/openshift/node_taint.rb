module BushSlicer
  class NodeTaint
    attr_reader :node, :effect, :key, :time_added, :value

    def initialize(node, taint_spec)
      @node = node

      case taint_spec
      when Hash
        @effect = taint_spec["effect"].freeze
        @key = taint_spec["key"].freeze
        @time_added = taint_spec["timeAdded"].freeze
        @value = taint_spec["value"].freeze
      when String
        m = taint_spec.match /^([[:alnum:]]+)=([[:alnum:]]+):([[:alnum:]]+)$/
        @key = m[1].freeze
        @value = m[2].freeze
        @effect = m[3].freeze
        raise "bad taint spec '#{taint_spec.inspect}'" unless @effect
      else
        raise "cannot create a taint off a: #{taint_spec.inspect}"
      end
    end

    def conflicts?(taint)
      raise "#{taint.inspect} is not a taint" unless self.class === taint

      key == taint.key && effect == taint.effect
    end

    def delete_str
      @delete_str ||= "#{key}:#{effect}-"
    end

    def cmdline_string
      @cmdline_string ||= "#{key}=#{value}:#{effect}".freeze
    end
    alias to_s cmdline_string

    def inspect
      "#<#{self.class} #{cmdline_string}"
    end

    ############### take care of object comparison ###############

    def ==(t)
      t.kind_of?(self.class) && node == t.node &&
        key == t.key && value == t.value && effect == t.effect
    end
    alias eql? ==

    def hash
      self.class.name.hash ^ node.hash ^ key.hash ^ value.hash ^ effect.hash
    end
  end
end
