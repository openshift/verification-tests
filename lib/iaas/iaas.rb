require 'yaml'

module BushSlicer
  module IAAS
    # will select the configured iaas provider and create the required iaas object to query the API
    def self.select_provider(env)
      provider_name = Infrastructure.new(name: "cluster", env: env).platform

      if provider_name
        case provider_name
        when "OpenStack"
          return {:type => "openstack", :provider => self.init_openstack(env)}
        when "AWS"
          return {:type => "aws", :provider => self.init_aws(env)}
        when "GCP"
          return {:type => "gcp", :provider => self.init_gcp(env)}
        when "Azure"
          return {:type => "azure", :provider => self.init_azure(env)}
        when "None"
          return {:type => "none", :provider => nil}
        else
          raise "The IAAS provider #{provider_name} is currently not supported by test framework!"
        end
      end
      raise "There is no IAAS provider configured for this instance of OpenShift!"
    end


    def self.init_openstack(env)
      # get the config of the IAAS instance
      secret = Secret.new(name: "openstack-credentials", project: Project.new(name: 'kube-system', env: env))
      iaas_conf = secret.value_of("clouds.conf", user: :admin).split("\n")
      iaas_conf_params = {}

      iaas_conf.each do |line|
        params = line.split("=")
        if params.length < 2
          next
        end
        iaas_conf_params[params[0].strip] = params[1].strip.gsub('"', '')
      end

      return BushSlicer::OpenStack.new(
        :url => iaas_conf_params['auth-url'] + "/auth/tokens",
        :user => iaas_conf_params["username"],
        :password => iaas_conf_params["password"],
        :tenant_id => iaas_conf_params["tenant-id"]
      )
    end

    def self.init_aws(env)
      aws_cred = {}

      secret = Secret.new(name: "aws-creds", project: Project.new(name: 'kube-system', env: env))
      key = secret.value_of("aws_access_key_id", user: :admin)
      skey = secret.value_of("aws_secret_access_key", user: :admin)

      return Amz_EC2.new(access_key: key, secret_key: skey)
    end

    def self.init_gcp(env)
      secret = Secret.new(name: "gcp-credentials", project: Project.new(name: 'kube-system', env: env))
      auth_json = secret.value_of("service_account.json", user: :admin)
      # type token is for bearer token downloaded from instance metadata
      # return GCE.new(:token_json => token_json, :auth_type => "token")
      json_file = Tempfile.new("json_cred_", Host.localhost.workdir)
      json_file.write(auth_json)
      json_file.close
      return GCE.new(:json_cred => json_file.path, :auth_type => "json",
                     :avoid_garbage_collection => json_file)
    end

    def self.init_azure(env)
      secret = Secret.new(name: "azure-credentials", project: Project.new(name: 'kube-system', env: env))
      auth = {}
      auth[:tenant_id] = secret.value_of("azure_tenant_id", user: :admin)
      auth[:client_id] = secret.value_of("azure_client_id", user: :admin)
      auth[:client_secret] = secret.value_of("azure_client_secret", user: :admin)

      return BushSlicer::Azure.new(
        :location => secret.value_of("azure_region", user: :admin),
        :subscription_id => secret.value_of("azure_subscription_id", user: :admin),
        :auth => auth,
        :resource_group => secret.value_of("azure_resourcegroup", user: :admin)
      )
    end
  end
end
