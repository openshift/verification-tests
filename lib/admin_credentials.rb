require 'base64'
require 'openssl'
require 'yaml'

module BushSlicer
  class MasterOsAdminCredentials
    include Common::Helper

    attr_reader :env, :opts

    def initialize(env, **opts)
      @env = env
      @opts = opts
    end

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
        conf = YAML.load(res[:response])
        uhash = conf["users"].first # minify should show us only current user

        crt = uhash["user"]["client-certificate-data"]
        key = uhash["user"]["client-key-data"]

        return APIAccessor.new(
          id: "admin",
          client_cert: OpenSSL::X509::Certificate.new(Base64.decode64(crt)),
          client_key: OpenSSL::PKey::RSA.new(Base64.decode64(key)),
          env: env
        )
      else
        logger.error(res[:response])
        raise "error getting kubeconfig from master #{master_host.hostname}, see log"
      end
    end
  end
end
