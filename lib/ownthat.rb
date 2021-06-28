require 'json'

require 'common'
require 'collections'
require 'cucuhttp'

module BushSlicer
  # let you operate a git repo
  class OwnThat
    include Common::Helper
    include CollectionsIncl
    attr_reader :url

    def initialize(url: nil, http_opts: {}, owner: nil)
      @url = url || conf[:services, :ownthat_allocator, :url]
      @owner = owner
      @http_opts = conf[:services, :ownthat_allocator, :http_opts] || {}
      @http_opts = @http_opts.merge http_opts

      # make sure ca_paths are absolute
      if @http_opts[:ssl_ca_file]
        @http_opts[:ssl_ca_file] = expand_path(@http_opts[:ssl_ca_file])
      end
      if @http_opts[:ssl_ca_path]
        @http_opts[:ssl_ca_path] = expand_path(@http_opts[:ssl_ca_path])
      end

      @http_opts = deep_freeze(deep_merge(@http_opts, http_opts))

      raise "need url" unless @url
    end

    def owner
      @owner ||= EXECUTOR_NAME
    end

    def locks_url
      @locks_url ||= File.join(url, "locks")
    end

    def update_url
      @update_url ||= File.join(locks_url, "by_values")
    end

    def from_pool_url
      @update_url ||= File.join(locks_url, "from_pool")
    end

    def http_opts(user_opts = {})
      opts = deep_merge(@http_opts, user_opts)
      opts[:headers] ||= {}
      opts[:headers][:accept] ||= "application/json"
      opts[:headers][:content_type] ||= "application/json"
      return opts
    end

    def request(method, url, payload, retries = 5)
      if payload.kind_of?(Hash)
        payload = payload.to_json
      end
      result = Http.request(url: url, method: method,
                            **http_opts, payload: payload)

      case
      when result[:success]
        return JSON.load(result[:response])
      when result[:exitstatus] == 404
        raise "HTTP server does not know about locks?"
      when [403, 401].include?(result[:exitstatus])
        raise "please specify correct username and password for ownthat server"
      when result[:exitstatus].between?(400, 499)
        # reserved by somebody else
        return false
      when result[:exitstatus] >= 500
        # some server error, good to retry a few times
        if retries > 0
          sleep 10
          return request(method, url, payload, retries - 1)
        else
          raise "OwnThat: internal server error while managing lock, see log"
        end
      else
        if result[:error]
          raise result[:error]
        else
          raise "unknown error"
        end
      end
    end

    def reserve(namespace, resource, expires, owner = self.owner)
      # no need to nest because of wrap_parameters in app controller
      payload = {
        namespace: namespace,
        resource: resource,
        expires: expires,
        owner: owner
      }

      request(:post, locks_url, payload)
    end

    def reserve_from_pool(namespace, pool, expires, owner = self.owner)
      payload = {
        namespace: namespace,
        poolname: pool,
        expires: expires,
        owner: owner
      }

      request(:post, from_pool_url, payload)
    end

    def update(namespace, resource, expires, owner = self.owner)
      # no need to nest because of wrap_parameters in app controller
      payload = {
        namespace: namespace,
        resource: resource,
        expires: expires,
        owner: owner
      }

      request(:patch, update_url, payload)
    end

    def release(namespace, resource, owner = self.owner)
      update(namespace, resource, 0, owner)
    end
  end
end
