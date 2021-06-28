require 'cgi'
require 'oga'
require 'uri'

require 'cucuhttp'

module BushSlicer
  # this file hosts necessary logic to login into OpenShift via username and
  # password
  module LoginIncl
    # @param [String] user the username we want token for
    # @return [String]
    def new_token_by_password(user:, password:, env:)
      # try challenging client auth
      res = oauth_bearer_token_challenge(
        server_url: env.api_endpoint_url,
        user: user,
        password: password,
        proxy: env.client_proxy
      )

      if res[:exitstatus] == 401 && res[:headers]["link"]
        # looks like we are directed at using web auth of some sort
        login_url = res[:headers]["link"][0][/(?<=<).*(?=>)/]
        Http.logger.info("trying to login via web at #{login_url}")
        res = web_bearer_token_obtain(user: user, password: password,
                                      login_url: login_url,
                                      proxy: env.client_proxy)
      end

      unless res[:success]
        msg = "Error getting bearer token, see log"
        if res[:error]
          raise res[:error] rescue raise msg rescue e=$!
        else
          raise msg rescue e=$!
        end
        Http.logger.error(e) # default error printing exclude cause
        raise e
      end

      return res[:token], res[:valid_until]
    end

    # try to obtain token via web login with the supplied user's name and
    #   password
    # @param [String] login_url the address where we are directed to log in
    # @param [String] user the user to get a token for
    # @return [BushSlicer::ResultHash] (:token key should be set on success)
    def web_bearer_token_obtain(user:, password:, login_url:, proxy: nil)
      obtain_time = Time.now
      proxy_opt = {}
      proxy_opt[:proxy] = proxy if proxy

      res = BushSlicer::Http.http_request(method: :get, url: login_url, **proxy_opt)
      return res unless res[:success]

      cookies = res[:cookies]
      login_page = Oga.parse_html(res[:response])
      login_action = login_page.css("form#kc-form-login").attribute("action").first&.value

      unless login_action
        res[:success] = false
        raise "could not find login form" rescue res[:error] = $!
        return res
      end

      res = BushSlicer::Http.http_request(method: :post, url: login_action, cookies: cookies, payload: {username: user, password: password}, **proxy_opt)

      if res[:exitstatus] == 302
        redir302 = res[:headers]["location"].first
        # for some user GET returns 500 without accept header; dunno why
        headers = {
          #user_agent: "Mozilla/5.0 (X11; Fedora; Linux x86_64; rv:55.0) Gecko/20100101 Firefox/55.0",
          user_agent: "Ruby RestClient #{RestClient.version}",
          # simple */* doesn't work, also dunno why
          accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          # accept_language: "bg,en-US;q=0.7,en;q=0.3",
          # referer: login_action
        }

        res = BushSlicer::Http.http_request(method: :get, url: redir302, cookies: cookies, headers: headers, **proxy_opt)
      end

      return res unless res[:success]

      token_page = Oga.parse_html(res[:response])
      res[:token] = token_page.css('code').first&.text
      res[:valid_until] = obtain_time + 24 * 60 * 60

      unless res[:token]
        res[:success] = false
        raise "cannot find token on page" rescue res[:error] = $!
      end

      return res
    end

    # @param [String] server_url e.g. "https://master.cluster.local:8443"
    # @param [String] user the username to get a token for
    # @param [String] password
    # @return [BushSlicer::ResultHash]
    # @note curl -u joe -kv -H "X-CSRF-Token: xxx" 'https://master.cluster.local:8443/oauth/authorize?client_id=openshift-challenging-client&response_type=token'
    def oauth_bearer_token_challenge(server_url:, user:, password:, proxy: nil)
      # :headers => {'X-CSRF-Token' => 'xx'} seems not needed
      opts = {:user=> user,
              :password=> password,
              :max_redirects=>0,
              :params=> {"client_id"=>"openshift-challenging-client", "response_type"=>"token"},
              :method=>"GET"
      }
      oauth_opts = {:url => "#{server_url}/.well-known/oauth-authorization-server",
                    :method=> "GET"
      }

      if proxy
        opts[:proxy] = proxy
        oauth_opts[:proxy] = proxy
      end

      res_oauth = Http.request(**oauth_opts)

      if res_oauth[:exitstatus] == 200
        opts[:url] = "#{JSON.parse(res_oauth[:response])["authorization_endpoint"]}"
      else
        opts[:url] = "#{server_url}/oauth/authorize"
      end

      res = Http.request(**opts)

      if res[:exitstatus] == 302 && res[:headers]["location"]
        begin
          uri = URI.parse(res[:headers]["location"][0])
          params = CGI::parse(uri.fragment)
          res[:token] = params["access_token"][0]
          res[:expires_in] = params["expires_in"][0]
          res[:valid_until] = Time.new + Integer(res[:expires_in])
          res[:success] = true
        rescue => e
          res[:error] = e
        end
      end

      return res
    end
  end

  module Login
    extend LoginIncl
  end
end
