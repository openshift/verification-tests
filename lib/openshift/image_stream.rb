require 'openshift/flakes/image_stream_tag_spec'
require 'openshift/flakes/image_stream_tag_status'

module BushSlicer
  # represents an OpenShift Image Stream
  class ImageStream < ProjectResource
    RESOURCE = "imagestreams"

    # # should be ready when all items in `Status` have tag
    def ready?(user:, quiet: false)
      res = get(user: user, quiet: quiet)

      if res[:success]
        res[:success] =
          res[:parsed]["status"]["tags"] &&
          res[:parsed]["status"]["tags"].length > 0 &&
          res[:parsed]["status"]["tags"].all? { |c|
            c["items"] && c["items"].length > 0
          }
      end

      return res
    end

    def docker_image_repository(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'dockerImageRepository')
    end

    def public_docker_image_repository(user: nil, cached: false, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      if rr.dig('status').key?('publicDockerImageRepository')
        return rr.dig('status', 'publicDockerImageRepository')
      else
        return "no publicDockerImageRepository added"
      end
    end

    def docker_registry_ip_or_hostname(user)
      return self.docker_image_repository(user).match(/[^\/]*\//)[0]
    end

    def tag_statuses(user: nil, cached: true, quiet: false)
      unless cached && props[:status_tags]
        rr = raw_resource(user: user, cached: cached, quiet: quiet)
        props[:status_tags] = rr.dig('status', 'tags').map { |tag|
          ImageStreamTagStatus.new(tag, self)
        }
      end
      return props[:status_tags]
    end

    def tag_status(name:, user: nil, cached: true, quiet: false)
      tag_statuses(user: user, cached: cached, quiet: quiet).find { |tag_status|
        tag_status.name == name
      }
    end

    def tags(user: nil, cached: true, quiet: false)
      unless cached && props[:spec_tags]
        rr = raw_resource(user: user, cached: cached, quiet: quiet)
        props[:spec_tags] = rr.dig('spec', 'tags').map { |tag|
          ImageStreamTagSpec.new(tag, self)
        }
      end
      return props[:spec_tags]
    end

    def tag(name:, user: nil, cached: true, quiet: false)
      tags(user: user, cached: cached, quiet: quiet).find { |tag|
        tag.name == name
      }
    end

    # @return [ImageStreamTagStatus] for the "latest" tag; then such tag name
    #   does not exist, it will return the first tag we see in image stream
    #   status
    def latest_tag_status(user: nil, cached: true, quiet: false)
      tag = tag_status(name: "latest", user: user, cached: cached, quiet: quiet)
      tag ||= tag_statuses(cached: true).first
      return tag
    end
  end
end
