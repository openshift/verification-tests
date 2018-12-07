require 'yaml'

module VerificationTests
  module IAAS
    # will select the configured iaas provider and create the required iaas object to query the API
    def self.select_provider(env)
      master_config = env.master_services[0].config.as_hash()

      api_server_args = master_config["kubernetesMasterConfig"]["apiServerArguments"]

      if api_server_args && api_server_args["cloud-provider"][0]
        iaas_provider_name = api_server_args["cloud-provider"][0]

        case iaas_provider_name
        when "openstack"
          return {:type => "openstack", :provider => self.init_openstack(env, api_server_args)}
        when "aws"
          return {:type => "aws", :provider => self.init_aws(env)}
        when "gce"
          return {:type => "gce", :provider => self.init_gce(env)}
        else
          raise "The IAAS provider #{iaas_provider_name} does not exist or is currently not supported by VerificationTests!"
        end
      end
      raise "There is no IAAS provider configured for this instance of Openshift!"
    end


    def self.init_openstack(env, api_server_args)
      # get the config of the IAAS instance
      iaas_conf_path = api_server_args["cloud-config"][0]
      iaas_conf = env.master_hosts[0].exec_admin("cat #{iaas_conf_path} | grep =")[:response].split("\n")
      iaas_conf_params = {}

      iaas_conf.each do |line|
        params = line.split("=")
        iaas_conf_params[params[0].strip] = params[1].strip
      end

      return VerificationTests::OpenStack.instance(
        :url => iaas_conf_params['auth-url'] + "tokens",
        :user => iaas_conf_params["username"],
        :password => iaas_conf_params["password"],
        :tenant_id => iaas_conf_params["tenant-id"]
      )
    end

    def self.init_aws(env)
      aws_cred = {}

      search_command = %{
        if [ -f /etc/origin/master/master.env ] ; then
          cat /etc/origin/master/master.env | grep AWS_
        elif [ -f /etc/sysconfig/atomic-openshift-master ] ; then
          cat /etc/sysconfig/atomic-openshift-master | grep AWS_
        elif [ -f /etc/sysconfig/atomic-openshift-node ] ; then
          cat /etc/sysconfig/atomic-openshift-node | grep AWS_
        fi
      }
      conn_cred = env.master_hosts[0].exec_admin(search_command, quiet: true)[:response].split("\n")

      key, skey = nil
      conn_cred.each { |c|
        cred = c.split("=")
        case cred[0].strip
        when "AWS_ACCESS_KEY_ID"
          key = cred[1].strip
        when "AWS_SECRET_ACCESS_KEY"
          skey = cred[1].strip
        end
      }

      return Amz_EC2.new(access_key: key, secret_key: skey)
    end

    def self.init_gce(env)
      token_json = env.master_hosts[0].exec_admin("curl -sS 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' -H 'Metadata-Flavor: Google'")[:response]

      return GCE.new(:token_json => token_json, :auth_type => "token")
    end
  end
end
