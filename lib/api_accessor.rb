module BushSlicer
  # common methods for all classes that have api access
  class APIAccessor
    attr_reader :env, :rest_preferences, :token, :expires, :client_cert,
      :client_key
    attr_writer :id

    # @param env [BushSlicer::Environment] the test environment of accessor
    # @param expires [Time, false] the time our auth is valid until, false
    #   if never expired
    # @param id [String] symbolic string to identify this API accessor, usually
    #   the user name or auth user name
    # @param token [String] auth bearer token in plain string format, if
    #   token auth is to be used
    # @param token_protected [Boolean] are allowed to invalidate token
    # @param client_cert [Array] see [CliExecutor::client_cert_from_cli], if
    #   cert auth is to be used
    # @param env [BushSlicer::Environment] the test environment of accessor
    # @return [User]
    def initialize(id: nil, token: nil, token_protected: true,
                   expires: false, client_cert: nil, client_key: nil, env:)
      @env = env
      @rest_preferences = {}
      @token = token
      @token_protected = token_protected
      self.id = id
      @expires = expires
      @client_cert = client_cert if client_cert
      @client_key = client_key if client_key

      unless token || (client_cert && client_key)
        raise "we need a token or a certificate to access OpenShift API"
      end
    end

    # @return [String] id as originally set or obtain username as returned by
    #   OpenShift API
    def id
      return @id if @id

      res = get_self
      if res.dig(:props, :name)
        return @id = res.dig(:props, :name)
      else
        raise "could not find user name in response: #{res[:response]}"
      end
    end

    def get_self
      #env.rest_request_executor.exec(user: self, auth: :bearer_token,
      #                                           req: :get_user,
      #                                           opts: {username: '~'})
      res = rest_request(:get_user, username: '~')

      if res[:success]
        return res
      else
        raise "error getting self from api: #{res[:response]}"
      end
    end

    # execute a rest request as this user
    # @param [Symbol] req the request to be executed
    # @param [Hash] opts the options needed for particular request
    # @note to select auth type, add :auth key to @rest_preferences
    def rest_request(req, **opts)
      env.rest_request_executor.exec(user: self, req: req, opts: opts)
    end

    def cli_exec(key, opts={})
      env.cli_executor.exec(self, key, opts)
    end

    # def client_cert
    #   if defined? @client_cert
    #     @client_cert
    #   else
    #     @client_cert ||= CliExecutor.client_cert_from_cli(self) # rescue false
    #   end
    # end

    def cert?
      !!client_cert && !!client_key
    end
    alias known_cert? cert?

    def token?
      !!token
    end
    alias known_token? token?

    # if there is no expiry time or at least 30 seconds until expiry time
    def active?
      !expires || expires > Time.now + 30
    end

    # @param [Boolean] uncache remove token from user object cache regardless of
    #   success
    def invalidate_token
      token_name = token
      if token.include? "sha256~"
         token_name = token.gsub("sha256~","")
         token_name = "sha256~" + Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(token_name),padding: false)
      end
      rest_request(:delete_oauthaccesstoken, token_to_delete: token_name)
    end

    def clean_up
      unless @token_protected
        invalidate_token
      end
    end

    ############### take care of object comparison ###############
    def ==(p)
      p.kind_of?(self.class) && env == p.env && expires == p.expires &&
        token == p.token && client_cert == p.client_cert && id == p.id &&
        client_key == p.client_key
    end
    alias eql? ==

    def hash
      self.class.name.hash ^ id.hash ^ env.hash ^ expires.hash ^
        token.hash ^ client_cert.hash ^ client_key.hash
    end

    ################# make pry inspection nicer ##################
    # @return string representation of accessor where `id` might be `nil` if
    #   not set yet; this is to avoid doing API accesses unintendedly
    def inspect
      "#<#{self.class} #{env.key}/#{@id}>"
    end

    # @return string representation of accessor where `id` might be `nil` if
    #   not set yet; this is to avoid doing API accesses unintendedly
    def to_s
      "#{self.class}:#{@id}@#{env.opts[:key]}"
    end
  end
end
