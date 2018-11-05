require 'base_helper'

module BushSlicer

  # this class should help with parsing endpoint port element
  class EndpointPort
    include Common::Helper

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    module ExportMethods
      def name
        return struct['name']
      end

      def port
        return struct['port']
      end

      def protocol
        return struct['protocol']
      end
    end

    include ExportMethods
  end
end
