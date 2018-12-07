module VerificationTests
  # represents a trigger structure inside a deployment/build config
  class ImageRef
    attr_reader :uri, :hash_type, :hash_value, :name

    # @param spec [String] similar to
    #   docker-registry.default.svc:5000/xplbz/ruby-hello-world-3@sha256:3980c036bc6d63fd432dcbf42cfeac41275253bd493820f2c0613e119b220d55
    # @param owner [Resource] which resource contained this reference
    def initialize(spec, owner)
      @raw = spec.freeze
      @uri, @name = spec.split("@", 2)
      @hash_type, @hash_value = name.split(":", 2)

      unless to_s && uri.freeze && hash_type.freeze && hash_value.freeze
        raise ArgumentError, "expecting image in format 'uri@hash_type:hash'" \
          " but it is #{spec}"
      end

      @owner = owner
    end

    # @return [Image]
    def image
      @image ||= Image.new(name: name, env: @owner.env)
    end

    # this is not as reliable as #image.repository but does not require
    #   admin access
    def repo
      unless @repo
        host_port = uri.split("/", 2).first
        if host_port&.include? "."
          @repo = host_port
        else
          # without dot the image is likely in form "openshift/something"
          @repo = ""
        end
      end
      return @repo
    end

    def to_s
      @raw
    end

    def ==(p)
      p.class == self.class && to_s == p.to_s
    end
    alias eql? ==

    def hash
      self.class.name.hash ^ to_s.hash
    end
  end
end
