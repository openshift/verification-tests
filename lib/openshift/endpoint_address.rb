require 'base_helper'
module VerificationTests

  # this class should help with parsing endpoint address element
  #   [3] pry(#<VerificationTests::Endpoints>)> addrs[0]
  # => {
  #          "ip" => "10.10.10.101",
  #    "nodeName" => "myhost.example.com",
  #   "targetRef" => {
  #                "kind" => "Pod",
  #                "name" => "test-rc-khm70",
  #           "namespace" => "47rxx",
  #     "resourceVersion" => "42845",
  #                 "uid" => "88c2eaec-11de-11e8-adf4-fa163e184fd4"
  #   }
  class EndpointAddress
    include Common::Helper

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    module ExportMethods
      def ip
        return IPAddr.new struct['ip']
      end

      def node_name
        return struct['nodeName']
      end

      def targetRef
        return ObjectReference.new struct['targetRef']
      end

    end

    include ExportMethods
  end
end
