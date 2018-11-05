require 'openshift/object_reference'
require_relative 'image_ref'

module BushSlicer
  # represents a trigger structure inside a deployment config
  class DeploymentConfigTrigger
    attr_reader :params, :spec, :from
    private :spec, :params

    SUBCLASSES = []

    def self.inherited(subclass)
      super
      SUBCLASSES << subclass
    end

    # @param spec [Hash] the trigger hash as found within deployment config
    #   triggers array
    # @param dc [DeploymentConfig] the original deployment config
    def initialize(spec, dc)
      if spec["type"] != self.class::TYPE
        raise(ArgumentError, "wrong type #{spec["type"]}")
      end
      @spec = spec

      if defined? self.class::PARAMS_KEY
        @params = spec[self.class::PARAMS_KEY]
        raise(ArgumentError, "no params") if @params.nil? || @params.empty?
      end
    end

    # @see #initialize
    def self.from_list(triggers, dc)
      if triggers.nil?
        trigger = { "type" => DeploymentConfigConfigChangeTrigger::TYPE }
        return [DeploymentConfigConfigChangeTrigger.new(trigger, dc)]
      end
      triggers.map do |trigger|
        clazz = SUBCLASSES.find { |tc| tc::TYPE == trigger["type"] }
        raise "unknown trigger type #{trigger["type"]}" unless clazz
        clazz.new trigger, dc
      end
    end

    def type
      self.class::TYPE
    end
  end

  class DeploymentConfigImageChangeTrigger < DeploymentConfigTrigger
    TYPE = "ImageChange".freeze
    PARAMS_KEY = "imageChangeParams".freeze

    attr_reader :dc
    private :dc

    # @param spec [Hash] the trigger hash as found within deployment config
    #   triggers array
    # @param dc [DeploymentConfig] the original deployment config
    def initialize(spec, dc)
      super
      @dc = dc
    end

    def from
      from_ref.resource(dc)
    end

    def from_ref
      unless defined? @from_ref
        case params.dig("from", "kind")
        when "ImageStreamTag"
          @from_ref = ObjectReference.new params["from"]
        else
          raise "unknown image change trigger from type " \
            "#{params.dig("from", "kind").inspect}"
        end
      end
      return @from_ref
    end

    def last_image
      image_ref = params['lastTriggeredImage']
      return image_ref ? ImageRef.new(image_ref, dc) : nil
    end
  end

  class DeploymentConfigConfigChangeTrigger < DeploymentConfigTrigger
    TYPE = "ConfigChange".freeze
  end
end
