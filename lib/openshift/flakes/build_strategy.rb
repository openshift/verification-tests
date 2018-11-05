require 'openshift/object_reference'

module BushSlicer
  class BuildStrategy
    SUBCLASSES = []

    attr_reader :owner, :spec
    private :owner, :spec

    # @param spec [Hash] the hash of the build specification, i.e. the
    #   `sourceStrategy` element
    # @param owner [Build, BuildConfig] that has this strategy
    def initialize(spec, owner)
      @owner = owner
      @spec = spec

      unless Hash === spec
        raise "spec should be a hash but it is: #{spec.inspect}"
      end
      unless Resource === owner
        raise "owner should have been a Resource but it is: #{owner.inspect}"
      end
    end

    def self.inherited(subclass)
      super
      SUBCLASSES << subclass
    end

    # @param spec [Hash] the hash of the whole build specification, i.e.
    #   the whole `strategy` element
    # @param owner [Build, BuildConfig] that has this strategy
    # @return [BuildStrategy]
    def self.from_spec(spec, owner)
      clazz = SUBCLASSES.find { |tc| tc::TYPE == spec["type"] }
      raise "unknown build strategy type #{spec["type"]}" unless clazz
      clazz.new spec[clazz::SPECNAME], owner
    end
  end

  class SourceBuildStrategy < BuildStrategy
    TYPE = "Source"
    SPECNAME = "sourceStrategy"

    def from_ref
      @from_ref ||= ObjectReference.new spec["from"]
    end

    def from
      from_ref.resource(owner)
    end
  end
end

