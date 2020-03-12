require 'base_helper'

module BushSlicer
  class ServiceMonitorEndpointSpec
    include Common::Helper

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    def bearer_token_file
      return struct['bearerTokenFile']
    end

    def bearer_token_secret
      return struct['bearerTokenSecret']
    end

    def key
      return self.bearer_token_secret.dig('key')
    end

    def interval
      return struct['interval']
    end

    def port
      return struct['port']
    end

    def path
      return struct['path']
    end

    def scheme
      return struct['scheme']
    end

    def tls_config
      return struct['tlsConfig']
    end

    def ca 
      return self.tls_config.dig('ca')
    end

    def ca_file
      return self.tls_config.dig('caFile')
    end

    def cert
      return self.tls_config.dig('cert')
    end

    def server_name
      return self.tls_config.dig('serverName')
    end

  end
end
