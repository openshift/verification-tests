module BushSlicer

  # this class should help with parsing report conditions
  class Condition

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    def last_transition_time
      return struct['lastTransitionTime']
    end

    def last_update_time
      return struct['lastUpdateTime']
    end

    def message
      return struct['message']
    end

    def reason
      return struct['reason']
    end

    def status
      return struct['status']
    end

    def type
      return struct['type']
    end
  end
end
