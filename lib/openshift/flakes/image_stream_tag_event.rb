require_relative 'image_ref'

module BushSlicer
  class ImageStreamTagEvent
    attr_reader :raw, :generation, :imageref, :created, :owner, :status
    private :raw, :owner

    def initialize(spec, status, owner)
      @raw = spec
      @generation = raw["generation"]
      @created = raw["created"] # Time object

      @status = status
      unless ImageStreamTagStatus === status
        raise "status should be ImageStreamTagStatus but is: #{status.inspect}"
      end

      @owner = owner
      unless Resource === owner
        raise "owner should be a Resource but is: #{owner.inspect}"
      end

      @imageref = ImageRef.new(raw["dockerImageReference"], owner)
    end
  end
end
