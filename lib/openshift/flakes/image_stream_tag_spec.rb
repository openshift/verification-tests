require 'openshift/object_reference'

module BushSlicer
  # this is the spec->tags section inside ImageStream and is very different
  #   from the ImageStreamTag resource
  class ImageStreamTagSpec
    attr_reader :raw, :name, :owner
    private :raw, :owner

    # @param spec [Hash] the tag specification hash
    # @param owner [ImageStream] the image stream containing this tag spec
    def initialize(spec, owner)
      @raw = spec
      @name = spec["name"]
      unless ImageStream === owner
        raise "owner should be a ImageStream but it is: #{owner.inspect}"
      end
      @owner = owner
    end

    # When kind is ImageStreamTag, it is a reference to a tag inside the owning
    #   ImageStream thus name is just the tag name, not the full
    #   "imagestream:tag" name of the ImageStreamTag resource.
    # Making method private as it is somehow messed up to alter the data
    #   and present it to caller without warning.
    private def from_ref
      unless @from_ref
        if raw["from"]["kind"] == "ImageStreamTag" &&
            !raw["from"]["name"].include?(":")
          raw_from = raw["from"].dup
          raw_from["name"] = "#{owner.name}:#{raw_from["name"]}"
        else
          raw_from = raw["from"]
        end
        @from_ref ||= ObjectReference.new raw_from
      end
      return @from_ref
    end

    def annotations
      raw['annotations']
    end

    # @see #from_ref about the special processing we are doing here
    def from
      from_ref.resource(owner)
    end
  end
end
