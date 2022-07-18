require 'base64'
require 'openssl'
require 'yaml'

module BushSlicer
  class AdminCredentials
    include Common::Helper

    attr_reader :env, :opts

    def initialize(env, **opts)
      @env = env
      @opts = opts
    end

    def accessor_from_kubeconfig(str)
        conf = YAML.load(str)
        uhash = conf["users"].first # minify should show us only current user

        if uhash.dig("user", "client-certificate-data") && uhash.dig("user", "client-key-data")
          crt = uhash["user"]["client-certificate-data"]
          key = uhash["user"]["client-key-data"]
          return APIAccessor.new(
            id: "admin",
            client_cert: OpenSSL::X509::Certificate.new(Base64.decode64(crt)),
            client_key: OpenSSL::PKey::RSA.new(Base64.decode64(key)),
            env: env
          )
        elsif uhash.dig("user", "token")
          token = uhash["user"]["token"]
          return APIAccessor.new(
            id: "admin",
            token: token,
            env: env
          )
        else
          raise "Require auth info in kubeconfig, but can not find client-certificate-data/client-key-data or token, #{conf}"
        end
    end
  end

  class MasterOsAdminCredentials < AdminCredentials

    private def master_host
      env.master_hosts.first
    end

    # @return [APIAccessor]
    def get
      res = master_host.exec_admin("cat /root/.kube/config", quiet: true)
      if !res[:success] && res[:response].include?("No such file or directory")
        # try to find kubeconfig in other locations
        locations = [["kubeconfig", "/etc/kubernetes/static-pod-resources"]]
        configs = locations.each do |pattern, path|
          find = master_host.exec_admin(
            "find '#{path}' -name '#{pattern}'", quiet: true)
          if find[:success] && !find[:response].empty?
            kubeconfig = find[:response].lines.first.strip
            res = master_host.exec_admin("cat '#{kubeconfig}'", quiet: true)
            break
          end
        end
      end

      if res[:success]
        logger.plain res[:response], false
        # host_pattern = '(?:' << env.master_hosts.map{|h| Regexp.escape h.hostname).join('|') << ')'
        # server = res[:stdout].scan(/^\s*server:\s.*#{host_pattern}.*$/)[0]
        # raise "cannot find master in remote admin kubeconfig" unless server
        # File.write(config, res[:stdout].gsub(/^\s*server:\s.*$/) {server} )
        # config_str = res[:stdout].gsub(/^(\s*server:)\s.*$/) {
        #   $1 + " " + env.api_endpoint_url
        # }
        return accessor_from_kubeconfig(res[:response])
      else
        logger.error(res[:response])
        raise "error getting kubeconfig from master #{master_host.hostname}, see log"
      end
    end
  end

  class URLKubeconfigCredentials < AdminCredentials
    def get
      # export OPENSHIFT_ENV_OCP4_ADMIN_CREDS_SPEC=file:///~/.kube/config
      if opts[:spec].start_with? 'file:///'
        path = File.expand_path(opts[:spec].split("file://")[1])
        raise "kubeconfig does not exists" unless File.exists? File.expand_path(path)
        config = File.open(path).read
      else
        url = opts[:spec]
        res = Http.get(url: url, raise_on_error: true)
        config = res[:response]
      end
      return accessor_from_kubeconfig(config)
    end
  end

  class AutoKubeconfigCredentials < AdminCredentials
    def get
      case opts[:spec]
      when nil
        MasterOsAdminCredentials.new(env, **opts).get
      when %r{://}
        URLKubeconfigCredentials.new(env, **opts).get
      else
        raise "unknown credentials specification: #{opts[:spec]}"
      end
    end
  end
end
