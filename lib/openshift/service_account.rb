require 'json'

require 'api_accessor_owner'
require 'openshift/secret'

module BushSlicer
  # represents OpenShift v3 Service account
  class ServiceAccount < ProjectResource
    include BushSlicer::APIAccessorOwner

    RESOURCE = "serviceaccounts"

    # set name to the full string "system:serviceaccount:#{project}:#{name}"
    # private def normalize_name
    #   if @name.include? ":"
    #     crap1, crap2, @shortname = @name.rpartition(":")
    #     @shortname.freeze
    #   else
    #     @shortname = @name.freeze
    #     @name = "system:serviceaccount:#{project.name}:#{@name}".freeze
    #   end
    # end

    def full_id
      "system:serviceaccount:#{project.name}:#{name}"
    end

    def load_bearer_tokens(user: nil, cached: true, quiet: true)
      get_secrets(user: user, cached: cached, quiet: quiet).
        select { |s| s.bearer_token?(user: user) }.
        each { |s| add_str_token(s.token(user: user), protect: true) }
    end

    def get_secret_names(user: nil, cached: true, quiet: true)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr["secrets"]&.map {|s| s['name']}
    end

    def get_secrets(user: nil, cached: true, quiet: true)
      user ||= default_user(user)
      secret_names = get_secret_names(user: user, cached: cached, quiet: quiet)
      Secret.list(user: user, project: project).select do |s|
        secret_names.include? s.name
      end
    end

    def create(by: nil)
      spec = {
        "kind" => "ServiceAccount",
        "apiVersion" => "v1",
        "metadata" => {
          "name" => name
        }
      }

      Tempfile.create(['serviceaccount','.json']) do |f|
        f.write(spec.to_json)
        f.close
        return default_user(by).cli_exec(:create, f: f.path, n: project.name)
      end
    end
  end
end
