module VerificationTests
  class PodVolumeSpec
    attr_reader :raw, :name, :owner
    private :raw, :owner

    private_class_method :new

    @subclasses = []

    # @see ::from_spec
    def initialize(spec, owner)
      @raw = spec
      @name = spec["name"]
      unless Pod === owner
        raise "owner should be a Pod but it is: #{owner.inspect}"
      end
      @owner = owner
    end

    # generate a volume spec object of approppriate class
    # @param spec [Hash] the tag specification hash
    # @param owner [Pod] the pod with this volume specification
    # @return [PodVolumeSpec] when volume type is not supported, returns a
    #   subtype of [UnknownPodVolumeSpec]
    def self.from_spec(spec, owner)
      type = raw_type(spec)
      clazz = @subclasses.find { |vs| vs::TYPE == type }
      clazz ||= UnknownPodVolumeSpec
      clazz.new spec, owner
    end

    # I think that there should always be one key in raw spec except for "name"
    #   but to be sure, let's assume zero or many keys are also possible
    #   and return a stable representation to be interpreted by caller
    private_class_method def self.raw_type(raw_spec)
      (raw_spec.keys - ["name"]).sort.join(" ")
    end

    def self.inherited(subclass)
      super
      subclass.class_eval { public_class_method :new }
      @subclasses << subclass
    end
  end
end

require_relative 'pod_volume_spec/pvc_pod_volume_spec'
require_relative 'pod_volume_spec/unknown_pod_volume_spec'
