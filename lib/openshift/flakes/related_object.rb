module BushSlicer

  # this class should help with parsing status.relatedObjects
  # https://github.com/openshift-qe/output_references/blob/master/clusteroperators/service-ca-operator.yaml
  class RelatedObject

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    def group
      return struct['group']
    end

    def name
      return struct['name']
    end

    def resource
      return struct['resource']
    end

  end
end
