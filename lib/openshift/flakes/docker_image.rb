module BushSlicer
  class DockerImage
    attr_reader :raw, :owner, :name
    private :raw, :owner

    def initialize(spec, owner)
      @raw = spec
      unless Resource === owner
        raise "owner must be an OpenShift Resource but it is: #{owner.inspect}"
      end
      @owner = owner
      @name = spec["name"]
      if !name || name.empty?
        raise "bad DockerImage spec: #{spec.to_json}"
      end
    end

    # @param reference [ObjectReference]
    # @param referer [Resource]
    # @return [ProjectResource]
    def self.from_reference(reference, referer)
      spec = {
        "kind" => "kind: DockerImage",
        "name" => reference.name
      }
      DockerImage.new spec, referer
    end
  end
end
