require 'rest-client'
require 'http-cookie'
require 'thread'

module BushSlicer
  module Http
    extend Common::Helper # include methods statically

    # perform a HTTP request
    #   Implementation resembles rest-client, for options see:
    #   * http://www.rubydoc.info/gems/rest-client/1.8.0/RestClient/Request
    #   Idea is to use this method instead of rest-client directly for
    #   convenience, as well in the future we may resamble same behavior using
    #   HttpClient which is more flexible but less convenient. My main concern
    #   is lack of per request proxy and request hooks with RestClient.
    #   Other than that it looks descent, supports replay logging which we may
    #   enable for better post fail debugging.
    # @param params [Hash, RestClient::ParamsArray] URL params to send on GET
    #   or x-www-form-urlencoded POST request
    # @param payload [Hash|String|File|Object] payload to send; here you put
    #   your string content, JSON or file data. For file to be recognized and
    #   automatically multipart mime to be chosen, you need to look at
    #   rest-client documentation.
    # @param headers [Hash] request heders
    # @yield [str_chunk] block will be called by rest-client (actually Net:HTTP)
    #   with chunks of body content as read by the remote server; note that
    #   HTTP status redirections, cookies, headers, etc. are all lost from
    #   response when a block is passed
    # @return [BushSlicer::ResultHash] standard bushslicer result hash;
    #   there is :headers populated as a [Hash] where headers are lower-cased
    def self.http_request(url:,
                          method:,
                          cookies: nil,
                          headers: {},
                          params: nil,
                          payload: nil,
                          user: nil, password: nil,
                          max_redirects: 10,
                          verify_ssl: nil,
                          ssl_ca_path: nil,
                          ssl_ca_file: nil,
                          ssl_client_cert: nil,
                          ssl_client_key: nil,
                          proxy: ENV['http_proxy'],
                          read_timeout: 30, open_timeout: 10,
                          quiet: false,
                          raise_on_error: false,
                          result: nil,
                          &block)
      rc_opts = {}
      rc_opts[:url] = url
      rc_opts[:cookies] = cookies if cookies
      rc_opts[:headers] = headers
      rc_opts[:headers][:params] = params if params
      rc_opts[:payload] = payload if payload
      rc_opts[:max_redirects] = max_redirects
      rc_opts[:method] = method
      rc_opts[:user] = user if user
      rc_opts[:password] = password if password
      rc_opts[:ssl_ca_file] = ssl_ca_file if ssl_ca_file
      rc_opts[:ssl_ca_path] = ssl_ca_path if ssl_ca_path
      if verify_ssl
        rc_opts[:verify_ssl] = verify_ssl
      elsif ssl_ca_path || ssl_ca_file
        rc_opts[:verify_ssl] = OpenSSL::SSL::VERIFY_PEER
      else
        rc_opts[:verify_ssl] = OpenSSL::SSL::VERIFY_NONE
      end
      rc_opts[:ssl_client_cert] = ssl_client_cert if ssl_client_cert
      rc_opts[:ssl_client_key] = ssl_client_key if ssl_client_key
      rc_opts[:read_timeout] = read_timeout
      rc_opts[:open_timeout] = open_timeout

      # RestClient.proxy = proxy if proxy && ! proxy.empty?
      if proxy && ! proxy.empty?
        proxy = "http://#{proxy}" unless proxy.include?("://")
        rc_opts[:proxy] = proxy
      end

      userstr = user ? "#{user}@" : ""
      result ||= {}
      result[:instruction] = "HTTP #{method.upcase} #{userstr}#{url}"
      result[:request_opts] = rc_opts
      result[:proxy] = RestClient.proxy if RestClient.proxy
      logger.info(result[:instruction]) unless quiet

      started = monotonic_seconds
      response = RestClient::Request.new(rc_opts).execute &block
    rescue => e
      result[:error] = e
      # REST request unsuccessful
      if e.respond_to?(:response) and e.response.respond_to?(:code) and e.response.code.kind_of? Integer
        # server replied with non-success HTTP status, that's ok
        response = e.response
      else
        # request failed badly, server/network issue?
        result[:exitstatus] = -1
        result[:cookies] = HTTP::CookieJar.new # empty cookies
        result[:headers] = {}
        result[:size] = 0
        response = exception_to_string(e)
      end
    ensure
      raise e if raise_on_error && Exception === e

      total_time = monotonic_seconds - started
      if block && !result[:error]
        logger.info("HTTP #{method.upcase} took #{'%.3f' % total_time} sec: #{response} bytes of data passed to block") unless quiet
        result[:exitstatus] ||= -1
        result[:response] = ""
        result[:success] = true # we actually don't know
        result[:cookies] = HTTP::CookieJar.new # empty cookies
        result[:headers] = {}
        result[:size] = response
      else
        logger.info("HTTP #{method.upcase} took #{'%.3f' % total_time} sec: #{result[:error] || response.description}") unless quiet
        result[:exitstatus] ||= response&.code || -1
        result[:response] = response
        result[:success] = result[:exitstatus].to_s[0] == "2"
        result[:cookies] ||= response&.cookie_jar
        result[:headers] ||= response&.raw_headers
        result[:size] ||= response&.size || 0
      end
      result[:total_time] = total_time

      logger.trace("HTTP response:\n#{result[:response]}")
      return result
    end
    class << self
      alias request http_request
    end

    # simple HTTP GET an URL
    def self.http_get(**request_opts, &block)
      return http_request(**request_opts, method: :get, &block)
    end
    class << self
      alias get http_get
    end

    # @note avoid putting too big numbrs to avoid OutOfMemory situations; we
    #   can implement an option to store less data per request to avoid that
    def self.flood_count(count:, concurrency:, noout: false, timeout: 600, **req_opts)
      res_queue = Queue.new
      threads = []
      req_opts[:quiet] = true unless req_opts.has_key?(:quiet)
      req_opts[:quiet] = true if noout

      req_proc = proc do
        begin
          # insert record before executing for better accuracy of total reqs
          res = {}
          res_queue << res
          Http.request(**req_opts, result: res)
        end while res_queue.size < count
      end

      started = monotonic_seconds
      concurrency.times { threads << Thread.new(&req_proc) }

      success = wait_for(timeout) {
        threads.all? { |t| t.join(1) }
      }
      time = monotonic_seconds - started

      unless success
        threads.each { |t| t.terminate }
        raise "concurrent HTTP requests did not complete within timeout"
      end

      results = []
      loop { (results << res_queue.pop(true)) rescue break }

      res = process_results(results)
      res[:wall_time] = time

      log_multi_result(res) unless noout

      return res
    end

    def self.log_multi_result(result)
      logger.info "#{result[:count]} HTTP requests " <<
      "completed in #{'%.3f' % result[:wall_time]} seconds, " <<
      "min: #{'%.3f' % result[:min]}, " <<
      "max: #{'%.3f' % result[:max]}, " <<
      "avg: #{'%.3f' % result[:avg]}, " <<
      "std_dev: #{'%.3f' % result[:stddev]}"
    end

    # @param results [Array<Hash>, Array<ResultHash>]
    def self.process_results(results)
      res = results.find {|r| !r[:success]} || results.first
      res[:count] = results.size
      count = res[:count].to_f
      res[:response] = results.map {|r| r[:response]}
      res[:total_time] = results.map {|r| r[:total_time]}
      res[:min] = res[:total_time].min
      res[:max] = res[:total_time].max
      res[:accumulated_time] = res[:total_time].reduce(0) {|s,t| s+t}
      res[:avg] = res[:accumulated_time] / count
      res[:stddev] = Math.sqrt(
        res[:total_time].inject(0) {|s,t| s+(t-res[:avg])**2} / (count - 1).to_f
      )

      return res
    end

    # @note calculate stddev, etc using Welford's method as resultset
    #   would usually be much larger than count limited flooding
    def self.flood_duration(duration:, concurrency:, **req_opts)
      # TODO
    end
  end
end
