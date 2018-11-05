require 'openshift/project_resource'

module BushSlicer
  # represents an OpenShift Image Stream Tag
  class ImageStreamTag < ProjectResource
    RESOURCE = "imagestreamtags"

    def digest(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('image', 'metadata', 'name')
    end

    def docker_version(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('image', 'dockerImageMetadata', 'DockerVersion')
    end

    def annotations(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('image', 'metadata', 'annotations')
    end

    def labels(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('image', 'dockerImageMetadata', 'Config', 'Labels')
    end

    def from(user:, cached: false, quiet: false)
      return raw_resource(user: user, cached: cached, quiet: quiet).dig("tag", "from", "name")
    end

    def config_user(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('image', 'dockerImageMetadata', 'Config', 'User')
    end

    def config_env(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('image', 'dockerImageMetadata', 'Config', 'Env')
    end

    def config_cmd(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('image', 'dockerImageMetadata', 'Config', 'Cmd')
    end

    def workingdir(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('image', 'dockerImageMetadata', 'Config', 'WorkingDir')
    end

    def exposed_ports(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('image', 'dockerImageMetadata', 'Config', 'ExposedPorts')
    end

    def image_layers(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('image', 'dockerImageLayers')
    end
  end
end
