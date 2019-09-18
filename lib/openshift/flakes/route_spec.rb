require 'base_helper'

module BushSlicer

  # this class should help with parsing route specifications
  class RouteSpec
    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    def  host
      return struct['host']
    end

    def path
      struct['path']
    def

    def target_port
      return struct.dig('port', 'targetPort')
    end

    def subdomain
      return struct['subdomain']
    end

    def tls_insecure_edge_termination_policy
      return struct.dig('tls', 'insecureEdgeTerminationPolicy')
    end

    def tls_termination
      return struct.dig('tls', 'termination')
    end

    def tls_certificate
      return struct.dig('tls', 'certificate')
    end

    def tls_key
      return struct.dig('tls', 'key')
    end

    def tls_ca_certificate
      return struct.dig('tls', 'caCertificate')
    end

    def tls_destination_ca_certificate
      return struct.dig('tls', 'destinationCACertificate')
    end

    def target_kind
      return struct.dig('to', 'kind')
    end

    def target_name
      return struct.dig('to', 'name')
    end

    def target_weight
      return struct.dig('to', 'weight')
    end

    def wildcard_policy
      return struct['wildcardPolicy']
    end
  end
end
