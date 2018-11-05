require 'base_helper'

module BushSlicer
  # pls reference to kubernetes doc for more details
  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.9/#objectreference-v1-core
  # targetRef is a sub-component of a endpoint address
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
  class ObjectReference
    include Common::Helper

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    module ExportMethods
      def api_verison
        return struct['apiVersion']
      end

      def field_path
        return struct['fieldPath']
      end

      def kind
        return struct['kind']
      end

      def name
        return struct['name']
      end

      def namespace
        return struct['namespace']
      end

      def resource_version
        return struct['resourceVersion']
      end

      def uid
        return struct['uid']
      end

      # @param referer [Resource] the resource containing this reference
      # @return [Resource]
      def resource(referer)
        return @resource if @resource

        clazz = Object.const_get("::BushSlicer::#{kind}")
        @resource = clazz.from_reference(self, referer)
        return @resource
      end
    end

    include ExportMethods
  end
end
