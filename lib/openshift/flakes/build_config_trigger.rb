require_relative 'image_ref'
require 'openshift/object_reference'

module BushSlicer
  # represents a trigger structure inside a build config
  class BuildConfigTrigger
    attr_reader :params, :spec, :bc
    private :spec, :params, :bc

    SUBCLASSES = []

    def self.inherited(subclass)
      super
      SUBCLASSES << subclass
    end

    # @param spec [Hash] the trigger hash as found within build config
    #   triggers array
    # @param bc [BuildConfig] the original build config
    def initialize(spec, bc)
      if spec["type"] != self.class::TYPE
        raise(ArgumentError, "wrong type #{spec["type"]}")
      end
      @spec = spec
      @bc = bc

      if defined? self.class::PARAMS_KEY
        @params = spec[self.class::PARAMS_KEY]
        raise(ArgumentError, "no params") if @params.nil? || @params.empty?
      end
    end

    # @see #initialize
    def self.from_list(triggers, bc)
      triggers.map do |trigger|
        clazz = SUBCLASSES.find { |tc|
          defined?(tc::TYPE) && tc::TYPE == trigger["type"]
        }
        clazz ||= BuildConfigUnknownTrigger
        clazz.new trigger, bc
      end
    end

    def type
      self.class::TYPE
    end
  end

  class BuildConfigImageChangeTrigger < BuildConfigTrigger
    TYPE = "ImageChange"
    PARAMS_KEY = "imageChange"

    def from
      from_ref&.resource(bc) || bc.strategy.from
    end

    def from_ref
      unless defined? @from_ref
        case params.dig("from", "kind")
        when nil
          # according to docs we should check ImageStreamTag from strategy
          # oc explain buildconfig.spec.triggers.imageChange
          # but lets not generate a fake reference, shall we?
          @from_ref = nil
        when "ImageStreamTag"
          @from_ref = ObjectReference.new params["from"]
        else
          raise "unknown image change trigger from type " \
            "#{params.dig("from", "kind")}"
        end
      end
      return @from_ref
    end

    def last_image
      image_ref = params['lastTriggeredImageID']
      return image_ref ? ImageRef.new(image_ref, bc) : nil
    end
  end

  class BuildConfigSourceCodeTrigger < BuildConfigTrigger
    def secret
      @secret ||= Secret.new(name: secret_name, project: bc.project)
    end

    def secret_name
      @secret_name ||= params.dig("secretReference", "name") ||
        params["secret"] || raise("no secret specified in trigger")
    end
  end

  class BuildConfigGitHubTrigger < BuildConfigSourceCodeTrigger
    TYPE = "GitHub"
    PARAMS_KEY = "github"
  end

  class BuildConfigGitLabTrigger < BuildConfigSourceCodeTrigger
    TYPE = "GitLab"
    PARAMS_KEY = "gitlab"
  end

  class BuildConfigGenericTrigger < BuildConfigSourceCodeTrigger
    TYPE = "Generic"
    PARAMS_KEY = "generic"
  end

  class BuildConfigBitbucketTrigger < BuildConfigSourceCodeTrigger
    TYPE = "Bitbucket"
    PARAMS_KEY = "bitbucket"
  end

  class BuildConfigConfigChangeTrigger < BuildConfigTrigger
    TYPE = "ConfigChange"
  end

  class BuildConfigUnknownTrigger < BuildConfigTrigger
    TYPE = nil

    # empty constructor to avoid troubles
    def initialize(spec, bc)
    end
  end
end
