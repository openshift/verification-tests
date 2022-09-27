# frozen_string_literal: true

require 'cucuhttp'

module BushSlicer
  module PolarShift
    class Request
      include Common::Helper

      def initialize(options={})
        options = options.merge load_env

        svc_name = options[:service_name] || :polarshift

        if conf[:services, svc_name.to_sym]
          @options = conf[:services, svc_name.to_sym].merge options
        end

        # error checking to make sure the `private` repo is present
        if @options.nil?
          raise "\nCan't find polarshift credentials to do REST call.  Please check the `private` repo is cloned into your repo"
        end
        unless @options[:user]
          Timeout::timeout(120) {
            STDERR.puts "PolarShift user (timeout in 2 minutes): "
            @options[:user] = STDIN.gets.chomp
          }
        end
        unless @options[:password]
          STDERR.puts "PolarShift Password: "
          @options[:password] = STDIN.noecho(&:gets).chomp
        end

        # make sure ca_paths are absolute
        if @options[:ca_file]
          @options[:ca_file] = expand_private_path(@options[:ca_file],
                                                   public_safe: true)
        elsif @options[:ca_path]
          @options[:ca_path] = expand_private_path(@options[:ca_path],
                                                   public_safe: true)
        end

        unless @options[:user] &&
               @options[:password] &&
               !@options[:user].empty? &&
               !@options[:password].empty?
          raise "specify POLARSHIFT user and password"
        end
      end

      # put all vars POLARSHIFT_* into a hash, e.g.
      # export POLARSHIFT_BASE_URL='https://...'
      # export POLARSHIFT_USER=...
      # export POLARSHIFT_PASSWORD=...
      private def load_env
        # get any PolaShift configuration from environment
        opts = {}
        vars_prefix = "POLARSHIFT_"

        ENV.each do |var, value|
          if var.start_with? vars_prefix
            opt = var[vars_prefix.length..-1].downcase.to_sym
            opts[opt] = value
          end
        end

        return opts
      end

      private def test_case_opts
        @test_case_opts ||= opts_by_prefix("test_case_")
      end

      private def test_suite_opts
        @test_suite_opts ||= opts_by_prefix("test_suite_")
      end

      private def opts_by_prefix(prefix)
        prefix = "#{prefix}"
        res = {}
        opts.each do |key, value|
          keys = key.to_s
          if keys.start_with? prefix
            res[keys[prefix.size..-1].to_sym] = value
          end
        end
        return res.freeze
      end

      private def opts
        @options
      end

      private def base_url
        @base_url ||= opts[:base_url]
      end

      private def ssl_opts
        res_opts = {verify_ssl: OpenSSL::SSL::VERIFY_PEER}
        if opts[:ca_file]
          res_opts[:ssl_ca_file] = opts[:ca_file]
        elsif opts[:ca_path]
          res_opts[:ssl_ca_path] = opts[:ca_path]
        end

        return res_opts
      end

      private def common_opts
        {
          **ssl_opts,
          user: opts[:user],
          password: opts[:password],
          headers: {content_type: :json, accept: :json}
        }
      end

      def get_run(project_id, run_id, with_cases: "automation")
        params = with_cases ? {test_cases: with_cases} : {}
        Http.request_with_retry(
          method: :get,
          url: "#{base_url}project/#{project_id}/run/#{run_id}",
          params: params,
          raise_on_error: false,
          read_timeout: 120,
          **common_opts
        )
      end

      # get run with retries and raises on failure
      def get_run_smart(project_id, run_id, with_cases: "automation", timeout: 360)
        success = wait_for(timeout, interval: 15) {
          res = get_run(project_id, run_id, with_cases: with_cases)
          if res[:exitstatus] == 200
            return JSON.load(res[:response])["test_run"]
          elsif res[:exitstatus] == 202
            next
          else
            raise %Q{got status "#{res[:exitstatus]}" getting run "#{run_id}" from project "#{project_id}":\n#{res[:response]}}
          end
        }
        raise %Q{could not obtain run "#{run_id}" from project "#{project_id} within timeout of "#{timeout}" seconds}
      end

      def create_run(project_id:,
                     run_id: nil,
                     run_title: nil,
                     run_type: nil,
                     case_query: nil,
                     template_id: nil,
                     custom_fields: nil)
        create_opts = {}
        b = binding
        [
          :project_id,
          :run_id,
          :run_title,
          :run_type,
          :case_query,
          :template_id,
          :custom_fields
        ].each { |key|
          if b.local_variable_get(key)
            create_opts[key] = b.local_variable_get(key)
          end
        }


        Http.request_with_retry(
          method: :post,
          url: "#{base_url}project/#{project_id}/run",
          payload: create_opts.to_json,
          raise_on_error: false,
          **common_opts
        )
      end

      def create_run_smart(timeout: 360, **opts)
        res = create_run(**opts)
        if res[:exitstatus] == 202
          op_url = JSON.load(res[:response])["operation_result_url"]
          logger.info "to check operation status manually, you can: " \
            "curl '#{op_url}' -u user:thepassword"
          pr = wait_op(url: op_url, timeout: timeout)
        else
          raise %Q{got status "#{res[:exitstatus]}" creating a new test run:\n#{res[:response]}}
        end

        unless pr.dig("properties", "run_id")
          raise "faux create test run response: #{pr}"
        end

        return {
          run_id: pr["properties"]["run_id"],
          import_filter: pr["properties"]["import_filter"]
        }
      end

      def query_test_cases(project_id:,
                     case_query: nil,
                     template_id: nil,
                     custom_fields: nil)
        create_opts = {}
        b = binding
        [
          :project_id,
          :case_query,
          :template_id,
          :custom_fields
        ].each { |key|
          if b.local_variable_get(key)
            create_opts[key] = b.local_variable_get(key)
          end
        }


        Http.request_with_retry(
          method: :post,
          url: "#{base_url}project/#{project_id}/test-cases/query",
          payload: create_opts.to_json,
          raise_on_error: false,
          **common_opts
        )
      end


      def query_test_cases_smart(timeout: 360, **opts)
        valid_params =[:project_id, :case_query, :template_id, :custom_fields]
        invalids = opts.keys - valid_params
        # need to remove extra Hash keys that is not part of the valid parameters for method query_test_cases
        invalids.each { |i| opts.delete(i) }
        res = query_test_cases(**opts)
        if res[:exitstatus] == 202
          op_url = JSON.load(res[:response])["operation_result_url"]
          logger.info "to check operation status manually, you can: " \
            "curl '#{op_url}' -u user:thepassword"
          pr = wait_op(url: op_url, timeout: timeout)
        else
          raise %Q{got status "#{res[:exitstatus]}" creating a new test run:\n#{res[:response]}}
        end

        unless pr.dig("properties", "list")
          raise "faux query test cases response: #{pr}"
        end

        return {
          list: pr["properties"]["list"],
        }
      end

      # @param case_ids [Array<String>] test case IDs
      def get_cases(project_id, case_ids)
        Http.request_with_retry(
          method: :get,
          url: "#{base_url}project/#{project_id}/test-cases",
          params: {"case_ids" => case_ids},
          raise_on_error: false,
          **common_opts
        )
      end

      def get_cases_smart(project_id, case_ids, timeout: 360)
        list = []
        ## huge requests may fail with error 400 so lets limit ourselves
        #  #<Puma::HttpParserError: HTTP element QUERY_STRING is longer than the (1024 * 10) allowed length (was 10499)>
        case_ids.each_slice(200) do |ids|
          res = get_cases(project_id, ids)
          if res[:exitstatus] == 202
            wait_op(url: JSON.load(res[:response])["operation_result_url"],
                    timeout: timeout)
            res = get_cases(project_id, ids)
          end

          if res[:exitstatus] == 200
            list.concat JSON.load(res[:response])["test_cases"]
          else
            raise %Q{got status "#{res[:exitstatus]}" getting cases "#{ids}" from project "#{project_id}":\n#{res[:response]}}
          end
        end
        return list
      end

      # refresh PolarShift cache of test cases
      def refresh_cases(project_id, case_ids)
        Http.request_with_retry(
          method: :put,
          url: "#{base_url}project/#{project_id}/test-cases",
          payload: {case_ids: case_ids}.to_json,
          raise_on_error: false,
          **common_opts
        )
      end

      def refresh_cases_wait(project_id, case_ids, timeout: 360)
        res = refresh_cases(project_id, case_ids)
        if res[:exitstatus] == 202
          wait_op(url: JSON.load(res[:response])["operation_result_url"],
                timeout: timeout)
        else
          raise %Q{got status "#{res[:exitstatus]}" refreshing cases "#{case_ids}" in project "#{project_id}":\n#{res[:response]}}
        end
      end

      # @param updates [Array<Hash>]
      def update_caseruns(project_id, run_id, updates)
        unless Array === updates
          updates = [updates]
        end
        Http.request_with_retry(
          method: :post,
          url: "#{base_url}project/#{project_id}/run/#{run_id}/records",
          payload: {case_records: updates}.to_json,
          raise_on_error: false,
          **common_opts
        )
      end

      # @param project_id [String]
      # @param updates [Hash<String, Hash>] with format:
      #   {case_id => { field => value, ...}, ...}
      def update_test_case_custom_fields(project_id, updates)
        Http.request_with_retry(
          method: :put,
          url: "#{base_url}project/#{project_id}/update-test-cases-custom-fields",
          payload: {updates: updates}.to_json,
          raise_on_error: false,
          **common_opts
        )
      end

      # sends a test run results from cache to server
      # @param project_id [String]
      # @param run_id [String]
      def push_test_run_results(project_id, run_id, force: false)
        res = Http.request_with_retry(
          method: :put,
          url: "#{base_url}project/#{project_id}/run/#{run_id}/push",
          payload: {force_uploaded: force}.to_json,
          **common_opts
        )
        if res[:success]
          res[:parsed] = JSON.load(res[:response])
        end
        return res
      end

      # checks result of a PolarShift async operation (like getting test run)
      # @return [Hash] where "status" key denotes status
      # @raise on request failure
      def check_op(url: nil, id: nil)
        raise "specify operation URL or id" unless url || id
        url ||= "#{base_url}/polarion/request/#{id}"
        res = Http.request_with_retry(
          method: :get,
          url: url,
          raise_on_error: false,
          **common_opts
        )

        unless res[:success]
          raise "status #{res[:exitstatus]} trying to obtain result status:\n#{res[:response]}"
        end

        return JSON.load(res[:response])["polarion_request"]
      end

      def wait_op(url: nil, id: nil, timeout: 360)
        res = nil
        success = wait_for(timeout, interval: 15) {
          res = check_op(url: url, id: id)
          case res["status"]
          when "done"
            return res
          when "queued", "running"
            next
          when "failed"
            raise "PolarShift operation failed:\n#{res["error"]}"
          else
            raise "unknown operation status #{res["status"]}"
          end
        }
        unless success
          raise "timeout waiting for operation, still status: #{res["status"]}"
        end
      end

      def default_project
        opts.dig(:manager, :project) || raise("no project given")
      end
    end
  end
end
