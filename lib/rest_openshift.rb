require 'rest_helper'

module BushSlicer
  module Rest
    module OpenShift
      extend Helper

      def self.populate(path, base_opts, opts)
        populate_common("/apis/user.openshift.io/<oapi_version>", path, base_opts, opts)
      end

      class << self
        alias perform perform_common
      end

      # @since 3.3
      # {
      #   "major": "3",
      #   "minor": "3+",
      #   "gitCommit": "f1694b3",
      #   "gitVersion": "v3.3.0.27",
      #   "buildDate": "2016-08-29T14:44:33Z"
      # }
      def self.version(base_opts, opts)
        populate_common("/version", "/openshift", base_opts, opts)
        return perform(**base_opts, method: "GET") { |res|
          res[:props][:openshift] = res[:parsed]["gitVersion"]
          res[:props][:major] = res[:parsed]["major"]
          res[:props][:minor] = res[:parsed]["minor"]
          res[:props][:build_date] = res[:parsed]["buildDate"]
        }
      end

      def self.delete_oauthaccesstoken(base_opts, opts)
        populate("/oauthaccesstokens/<token_to_delete>", base_opts, opts)
        return perform(**base_opts, method: "DELETE")
      end

      def self.list_projects(base_opts, opts)
        populate("/projects", base_opts, opts)
        return perform(**base_opts, method: "GET")
      end

      def self.delete_project(base_opts, opts)
        populate("/projects/<project_name>", base_opts, opts)
        return perform(**base_opts, method: "DELETE")
      end

      def self.get_project(base_opts, opts)
        populate("/projects/<project_name>", base_opts, opts)
        return perform(**base_opts, method: "GET")
      end

      def self.get_user(base_opts, opts)
        populate("/users/<username>", base_opts, opts)
        return perform(**base_opts, method: "GET") { |res|
          res[:props][:name] = res[:parsed]["metadata"]["name"]
          res[:props][:uid] = res[:parsed]["metadata"]["uid"]
        }
      end

      # this usually creates a project in fact
      def self.create_project_request(base_opts, opts)
        base_opts[:payload] = {}
        # see https://bugzilla.redhat.com/show_bug.cgi?id=1244889 for apiVersion
        base_opts[:payload][:apiVersion] = opts[:oapi_version]
        base_opts[:payload]["displayName"] = opts[:display_name] if opts[:display_name]
        base_opts[:payload]["description"] = opts[:description] if opts[:description]
        # base_opts[:payload][:kind] = "ProjectRequest"
        base_opts[:payload][:metadata] = {name: opts[:project_name]}

        populate("/projectrequests", base_opts, opts)
        return Http.request(**base_opts, method: "POST")
      end

      def self.post_local_resource_access_reviews(base_opts, opts)
        base_opts[:payload] = {}
        base_opts[:payload][:apiVersion] = opts[:oapi_version]
        base_opts[:payload][:kind] = "LocalResourceAccessReview"
        base_opts[:payload][:verb] = opts[:verb]
        base_opts[:payload][:resource] = opts[:resource]
        project_name = opts[:project_name]
        populate("/namespaces/<project_name>/localresourceaccessreviews", base_opts, opts)
        return perform(**base_opts, method: "POST")
      end

      # did not find out how to use this one yet
      def self.create_oauth_access_token(base_opts, opts)
        base_opts[:payload] = {}
        base_opts[:payload]["expiresIn"] = opts[:expires_in] if opts[:expires_in]
        base_opts[:payload]["userName"] = opts[:user_name] if opts[:user_name]
        base_opts[:payload][:scopes] = opts[:scopes] if opts[:scopes]


        populate("/oauthaccesstokens", base_opts, opts)
        return perform(**base_opts, method: "POST") { |res|
          # res[:props][:name] = res[:parsed]["metadata"]["name"]
          # res[:props][:uid] = res[:parsed]["metadata"]["uid"]
        }
      end

      def self.rollback_deploy(base_opts, opts)
        base_opts[:payload] = {}
        base_opts[:payload][:spec] = {}
        base_opts[:payload][:spec][:from] = {name: opts[:deploy_name]}
        base_opts[:payload][:spec][:includeTriggers] = to_bool(opts[:includeTriggers])
        base_opts[:payload][:spec][:includeTemplate] = to_bool(opts[:includeTemplate])
        base_opts[:payload][:spec][:includeReplicationMeta] = to_bool(opts[:includeReplicationMeta])
        base_opts[:payload][:spec][:includeStrategy] = to_bool(opts[:includeStrategy])

        project_name = opts[:project_name]

        populate("/namespaces/<project_name>/deploymentconfigrollbacks", base_opts, opts)
        return Http.request(**base_opts, method: "POST")
      end

      def self.get_subresources_oapi(base_opts, opts)
        populate("/namespaces/<project_name>/<resource_type>/<resource_name>/status", base_opts, opts)
        return Http.request(**base_opts, method: "GET")
      end

      def self.post_role_oapi(base_opts, opts)
        base_opts[:payload] = {}
        base_opts[:payload]["kind"] = opts[:kind]
        base_opts[:payload]["apiVersion"] = opts[:api_version]
        base_opts[:payload]["verb"] = opts[:verb]
        base_opts[:payload]["resource"] = opts[:resource]
        base_opts[:payload]["user"] = opts[:user]

        populate("/namespaces/<project_name>/<role>", base_opts, opts)
        return Http.request(**base_opts, method: "POST")
      end

      def self.post_pod_security_policy_self_subject_reviews(base_opts, opts)
        base_opts[:payload] = File.read(expand_path(opts[:payload_file]))
        populate("/namespaces/<project_name>/podsecuritypolicyselfsubjectreviews", base_opts, opts)
        return perform(**base_opts, method: "POST")
      end

      def self.post_pod_security_policy_subject_reviews(base_opts, opts)
        base_opts[:payload] = File.read(expand_path(opts[:payload_file]))
        populate("/namespaces/<project_name>/podsecuritypolicysubjectreviews", base_opts, opts)
        return perform(**base_opts, method: "POST")
      end

      def self.post_pod_security_policy_reviews(base_opts, opts)
        base_opts[:payload] = File.read(expand_path(opts[:payload_file]))
        populate("/namespaces/<project_name>/podsecuritypolicyreviews", base_opts, opts)
        return perform(**base_opts, method: "POST")
      end

    end
  end
end
