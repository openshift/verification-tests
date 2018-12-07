require_relative 'image_stream_tag_event'

module VerificationTests
  # represents a tag status within an ImageStream, nothing to do with the
  #   ImageStreamTag resource
  class ImageStreamTagStatus
    include Common::Helper
    attr_reader :raw, :name, :owner
    private :raw, :owner

    def initialize(spec, owner)
      @raw = spec
      unless ImageStream === owner
        raise "owner should be a ImageStream but it is: #{owner.inspect}"
      end
      @owner = owner
      @name = spec["tag"]
      if !name || name.empty?
        raise "bad ImageStreamTagStatus spec: #{spec.to_json}"
      end
    end

    def tag
      owner.tag(name: name, cached: true)
    end

    def imageref
      # using the safe operator &. http://mitrev.net/ruby/2015/11/13/the-operator-in-ruby/
      events.first&.imageref
    end

    # the method returns `items` element but `event` name was chosen as in
    #   documentation, these items are described as "TagEvent array"
    # https://docs.okd.io/latest/rest_api/apis-image.openshift.io/v1.ImageStream.html
    def events
      if raw['items'].nil?
        return []
      else
        @events ||= raw["items"].map { |event_spec|
          ImageStreamTagEvent.new(event_spec, self, owner)
        }
      end
    end
  end
end
