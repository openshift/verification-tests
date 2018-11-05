require 'base_helper'

module BushSlicer
  # pls reference to kubernetes doc for more details
  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.9/#endpointsubset-v1-core
  class EndpointSubset
    include Common::Helper

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    module ExportMethods
      # return an Endpoint Addresses
      def addresses
        addrs = []
        struct['addresses'].each do | a |
          ea = EndpointAddress.new a
          addrs << ea
        end
        return addrs
      end

      # return an Endpoint Port
      def ports
        ports = []
        struct['ports'].each do | p |
          ep = EndpointPort.new p
          ports << ep
        end
        return ports
      end
    end

    include ExportMethods
  end
end
