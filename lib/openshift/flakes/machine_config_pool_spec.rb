require 'base_helper'

module BushSlicer

  class MachineConfigPoolSpec
    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end
    def configuration_source
      return struct.dig('configuration', 'source')
    end
  end
end
