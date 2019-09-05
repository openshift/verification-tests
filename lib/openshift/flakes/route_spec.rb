require 'base_helper'

module BushSlicer

  # this class should help with parsing route specifications
  class RouteSpec
    include Common::Helper

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    module ExportMethods
      def  host
        return struct['host']
      end

      def targetPort
        return struct.dig('port', 'targetPort')
      end

      def subdomain
        return struct['subdomain']
      end

      def tls_insecureEdgeTerminationPolicy
        return struct.dig('tls', 'insecureEdgeTerminationPolicy')
      end

      def tls_termination
        return struct.dig('tls', 'termination')
      end

      def to_kind
        return struct.dig('to', 'kind')
      end

      def to_name
        return struct.dig('to', 'name')
      end

      def to_weight
        return struct.dig('to', 'weight')
      end

      def wildcardPolicy
        return struct['wildcardPolicy']
      end

    end

    include ExportMethods

  end
end
