require "base64"

require 'common'

module BushSlicer
  # represents an OpenShift Secret
  class Secret < ProjectResource
    RESOURCE = "secrets"

    # see #raw_resource
    def type(user: nil, cached: true, quiet: true)
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      return obj['type']
    end

    # @param user [BushSlicer::User] the user to run cli commands with if needed
    def bearer_token?(user: nil, cached: true, quiet: true)
      type(user: user, cached: cached, quiet: quiet).include?('service-account-token') && raw_resource.dig('data', 'token')
    end

    # @param user [BushSlicer::User] the user to run cli commands with if needed
    # @return [String] bearer token
    def token(user: nil, cached: true, quiet: true)
      if bearer_token?(user: user, cached: cached, quiet: quiet)
        return value_of(:token)
      else
        raise "secret #{name} does not contain a token"
      end
    end

    def raw_value_of(key, user: nil, cached: true, quiet: true)
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      obj.dig("data", key.to_s)
    end

    def value_of(key, user: nil, cached: true, quiet: true)
      value = raw_value_of(key, user: user, cached: cached, quiet: quiet)
      value ? Base64.decode64(value) : nil
    end
  end
end
