module BushSlicer
  module APIAccessorOwner
    # add a token in plain string format to cached tokens
    # @param token [String] the bearer token
    def add_str_token(str_token, expires=nil, protect: false)
      unless cached_tokens.include? str_token
        add_api_accessor APIAccessor.new(
          id: new_api_accessor_id,
          token: str_token,
          token_protected: protect,
          expires: expires,
          env: env
        )
      end
    end

    private def cached_api_accessors
      @cached_api_accessors ||= []
    end

    # @return [APIAccessor] default api accessor
    private def api_accessor
      return cached_api_accessors[0] || raise("no api accessors for user #{name}")
    end

    [:cli_exec, :rest_request, :known_cert?].each do |meth|
      define_method(meth) do |*args, &block|
        api_accessor.public_send meth, *args, &block
      end
    end

    # generate a unique and readable id for api accessors; these are used
    # to generate kubeconfig files for the users
    private def new_api_accessor_id
      if cached_api_accessors.size == 0
        name
      else
        "#{name}--#{cached_api_accessors.size}"
      end
    end

    def add_api_accessor(accessor)
      unless cached_api_accessors.include? accessor
        if cached_api_accessors.find { |a| a.id == accessor.id }
          raise "duplicate API Accessor id #{a.id}"
        else
          cached_api_accessors << accessor
        end
      end
    end

    # will return user known oauth tokens
    # @note we do not encourage caching everything into this test framework,
    #   rather prefer discovering online state. Token is different though as
    #   without a token, one is unlikely to be able to perform any other
    #   operation. So we need to have at least limited token caching.
    def cached_tokens
      cached_api_accessors.select { |a|
        a.active? && a.token?
      }.map(&:token)
    end
  end
end
