#!/usr/bin/env ruby
# frozen_string_literal: true

"""
Utility to enable some PolarShift operations via CLI
"""

require 'commander'
require 'pathname'

require_relative 'common/load_path'

require 'common'
require "gherkin_parse"

require_relative "stompbus/stompbus"

module BushSlicer
  class PolarShiftCli
    include Commander::Methods
    include Common::Helper

    TCMS_RELEVANT_TAGS = ["admin", "destructive", "flaky", "smoke", "vpn"].freeze

    def initialize
      always_trace!
    end

    def run
      program :name, 'PolarShift CLI'
      program :version, '0.0.1'
      program :description, 'Tool to enable some PolarShift operations via CLI'

      #Commander::Runner.instance.default_command(:gui)
      default_command :help

      global_option('-p', '--project ID', 'Project ID to use')
      global_option('--polarshift URL', 'PolarShift URL')

      command :fiddle do |c|
        c.syntax = "#{__FILE__} fiddle"
        c.description = 'enter a pry shell to play with API'
        c.action do |args, options|
          setup_global_opts(options)
          require 'pry'
          binding.pry
        end
      end

      command :"update-automation" do |c|
        c.syntax = "#{$0} update-automation [options]"
        c.description = 'Update test case automation related fields.'
        c.option('--no-wait', "Wait on message bus for operation to complete.")
        c.action do |args, options|
          setup_global_opts(options)
          if args.empty?
            raise "please add Test Case IDs in the command line"
            exit false
          end

          project_id = project

          parser = GherkinParse.new
          cases_loc = parser.locations_for *args
          cases_spec = parser.spec_for cases_loc
          print_fileno(cases_loc)

          updates = generate_case_updates(project_id, cases_spec)

          # print what we are going to do to user
          updates.each do |c, updates|
            puts "Automation script field for #{HighLine.color c, :bold}:\n"
            updates.each do |field, update|
              puts "#{HighLine.color(field.to_s.upcase, :magenta, :bold)}: #{HighLine.color(update.strip, :green)}"
            end
            puts "======================================"
          end

          ## prepare user/password to the bus early to catch message
          if options.no_wait.nil?
            begin
              bus_client = msgbus.new_client
            rescue => e
              options.no_wait = true
              logger.warn "Connection to message bus failed, progress won't " \
                "be tracked"
              logger.info e
            end
          end

          puts "Updating cases: #{updates.keys.join(", ")}.."
          res = polarshift.
            update_test_case_custom_fields(project_id, updates)
          if res[:success]
            filter = JSON.load(res[:response])["import_msg_bus_filter"]
            unless filter && !filter.empty?
              puts "unknown importer response:\n#{res[:response]}"
              exit false
            end
            if options.no_wait.nil?
              puts "waiting for a bus message with selector: #{filter}"
              message = nil
              bus_client.subscribe(msgbus.default_queue, selector:filter) do |m|
                message = m
                bus_client.close
              end
              bus_client.join
              puts STOMPBus.msg_to_str(message)
            end
          else
            puts "HTTP Status: #{res[:exitcode]}, Response:\n#{res[:response]}"
            exit false
          end
        end
      end

      command :"create-run" do |c|
        c.syntax = "#{$0} create-run [options]"
        c.description = "Create a new test run\n\te.g. " \
          'tools/polarshift.rb create-run -f ../polarshift/req.json'
        c.option('-f', "--file FILE", "YAML file with create parameters.")
        c.option('--no-wait', "Skip waiting on message bus for operation to complete.")
        c.action do |args, options|
          setup_global_opts(options)

          unless options.file
            raise "Please specify file to read test run create options from"
          end

          unless File.exist? options.file
            raise "specified input file does not exist: #{options.file}"
          end

          params = YAML.load(File.read(options.file))
          Collections.hash_symkeys! params

          ## prepare user/password to the bus early to catch message
          if options.no_wait.nil?
            begin
              bus_client = msgbus.new_client
            rescue => e
              options.no_wait = true
              logger.warn "Connection to message bus failed, progress won't " \
                "be tracked"
              logger.info e
            end
          end

          pr = polarshift.create_run_smart(project_id: project, **params)

          quoted_run_id = "'" + pr[:run_id] + "'"

          puts "test run id: #{HighLine.color(quoted_run_id, :bright_blue)}"
          # TODO: move waiting using HTTP to Polarshift, msg goes before we can subscribe
          filter = pr[:import_filter]
          if options.no_wait.nil?
            puts "waiting for a bus message with selector: #{filter}"
            message = nil
            bus_client.subscribe(msgbus.default_queue, selector: filter) do |m|
              message = m
              bus_client.close
            end
            bus_client.join
            puts STOMPBus.msg_to_str(message)
          end
        end
      end

      command :"get-run" do |c|
        c.syntax = "#{$0} get-run [options]"
        c.description = "retrieve a test run Polarion\n\t" \
          "e.g. tools/polarshift.rb get-run my_run_id"
        c.option('-w', "--with_cases VALUE", "set 'with_case' filter with value; valid values are automation|full")
        c.option('-o', "--output FILE", "Write query result to file in JSON format")
        c.action do |args, options|
          setup_global_opts(options)

          if args.size != 1
            raise "command expects exactly one parameter being the test run id"
          end

          test_run_id = args.first
          if options.with_cases
            query_result = polarshift.get_run_smart(project, test_run_id, with_cases: options.with_cases)
          else
            query_result = polarshift.get_run_smart(project, test_run_id)
          end
          result = query_result
          pp(result)
          if options.output
            File.write(options.output, JSON.pretty_generate(result))
          end
        end
      end

      command :"clone-run" do |c|
        c.syntax = "#{$0} clone-run [options]"
        c.description = "clone a test run from Polarion\n\t" \
          "e.g. tools/polarshift.rb clone-run my_run_id"
        c.option('-s', "--status CASE_STAUTS", "testcase status to be cloned, passed, failed, default to all")
        c.option('-t', "--title RUN_TITLE", "Title of the clone run you wish to be")
        c.option('-e', "--subteam SUBTEAM_NAME", "the subteam to filter on")
        c.action do |args, options|
          setup_global_opts(options)

          if args.size != 1
            raise "command expects exactly one parameter being the test run id"
          end

          test_run_id = args.first
          clone_run(test_run_id: test_run_id, options: options)
        end
      end

      command :"query-cases" do |c|
        c.syntax = "#{$0} query-cases [options]"
        c.description = "run query for test cases\n\te.g. " \
          'tools/polarshift.rb query-cases -f ../polarshift/req.json'
        c.option('-f', "--file FILE", "YAML file with create parameters.")
        c.option('-o', "--output FILE", "Write query result to file.")
        c.action do |args, options|
          setup_global_opts(options)

          unless options.file
            raise "Please specify file to read test run create options from"
          end

          unless File.exist? options.file
            raise "specified input file does not exist: #{options.file}"
          end

          params = YAML.load(File.read(options.file))
          Collections.hash_symkeys! params

          pr = polarshift.query_test_cases_smart(project_id: project, **params)

          cases = pr[:list]

          puts "#{HighLine.color(cases.join("\n"), :bright_blue)}"
          if options.output
            File.write options.output, cases.join("\n")
          end
        end
      end

      command :"push-run" do |c|
        c.syntax = "#{$0} push-run [options]"
        c.description = "Pushes test run results from cache to backend\n\t" \
          "e.g. tools/polarshift.rb push-run -p my_project my_run_id"
        c.option("--force", "Force push even without changes since last push.")
        c.action do |args, options|
          setup_global_opts(options)

          if args.size != 1
            raise "command expects exactly one parameter being the test run id"
            exit false
          end

          res = polarshift.push_test_run_results(project, args.first,
                                                 force: !!options.force)
          if res[:success]
            puts res[:parsed]["description"]
          else
            puts "HTTP Status: #{res[:exitcode]}, Response:\n#{res[:response]}"
            exit false
          end
        end
      end

      run!
    end

    # @param project [String] project id
    # @param cases_spec [Hash<String, Hash>] structure like:
    #   case_id_1:
    #     scenario: scenario name
    #     file: file name relative to cucumber dir
    #     args:
    #       some: arg if any
    #   case_id_2: ...
    def generate_case_updates(project, cases_spec)
      updates = normalize_tags(project, cases_spec).map do |case_id, spec|
        tags = spec.delete("tags")
        update = {
          caseautomation: "automated",
          automation_script: {"cucushift" => spec}.to_yaml
        }
        update[:tags] = tags if tags
        [ case_id, update ]
      end
      return Hash[updates]
    end

    def print_fileno(locations)
      puts "To execute listed test cases on command line, use this filter:"
      home = Pathname.new(::BushSlicer::HOME)
      puts HighLine.color(
        locations.
          map(&:last).
          map {|c| c.join(?:)}.
          map {|c| Pathname.new(c).relative_path_from(home).to_s}.
          join(" "),
        :bright_blue
      )
    end

    # Allows you to modify automation fields for test cases
    # @param project [String]
    # @param case_ids [Array<String>]
    # @yield [case_spec, test_case] the block should return updates wanted for
    #   each test case, e.g. `{"tags": "tag1 tag2 tag3"}`
    def sed_automation(project, case_ids)
      puts "Getting cases: #{case_ids.join(", ")}.."
      polarshift.refresh_cases_wait(project, case_ids)
      cases_raw = polarshift.get_cases_smart(project, case_ids)

      updates = {}
      cases_raw.each do |tc_raw|
        tc = PolarShift::TestCase.new(tc_raw, polarshift)
        update = yield tc_raw, tc
        if update && !update.empty?
          updates[tc.id] = update
        end
      end


      puts "Updating cases: #{updates.keys.join(", ")}.."

      require 'pry'; binding.pry
      res = polarshift.
        update_test_case_custom_fields(project, updates)
      if res[:success]
        filter = JSON.load(res[:response])["import_msg_bus_filter"]
        unless filter && !filter.empty?
          puts "unknown importer response:\n#{res[:response]}"
          raise res[:response]
        end
      else
        puts "HTTP Status: #{res[:exitcode]}, Response:\n#{res[:response]}"
        raise res[:response]
      end
    end

    # @return [Array<String, Array>] same as [GherkinParse#cases_spec] but
    #   we do not convert to Hash as it is not needed
    # @see #generate_case_updates for parameter description
    def normalize_tags(project, cases_spec)
      casetags = {}
      cases_spec.each do |case_id, spec|
        tags = spec.delete("tags")
        if tags && !tags.empty?
          raise "bad tag format: #{tags}" unless Array === tags
          tags.each do |tag|
            raise "bad tag value: #{tag.inspect}" unless String === tag
          end
          casetags[case_id] = tags
        else
          casetags[case_id] = []
        end
      end

      puts "Getting cases: #{casetags.keys.join(", ")}.."
      polarshift.refresh_cases_wait(project, casetags.keys)
      cases_raw = polarshift.get_cases_smart(project, casetags.keys)

      cases = cases_raw.map { |c| PolarShift::TestCase.new(c, polarshift) }

      cases.each do |tcms_case|
        final_tags = casetags[tcms_case.id] & TCMS_RELEVANT_TAGS
        final_tags.concat(tcms_case.tags - TCMS_RELEVANT_TAGS)
        if final_tags != tcms_case.tags
          cases_spec[tcms_case.id]["tags"] = final_tags.join(" ")
        end
      end

      return cases_spec
    end

    def project
      polarshift.default_project
    end

    def polarshift
      @polarshift ||= PolarShift::Request.new(**opts)
    end

    def msgbus
      @msgbus ||= STOMPBus.new
    end

    def opts
      @opts || raise('please first call `setup_global_opts(options)`')
    end

    # @param options [Ostruct] options as processed by Commander
    def setup_global_opts(options)
      opts = options.default
      if opts[:project]
        opts[:manager] = { project: opts.delete(:project) }
      end
      if opts[:polarshift]
        opts[:base_url] = opts.delete(:polarshift)
      end
      @opts = opts
    end

    # given a query_result from a call to get_smart_run()
    # @return Array of testcase IDs
    def extract_test_case_ids(query_result)
      query_result['records']['TestRecord'].map { |tr| tr['test_case']['id'] }
    end

    # the Custom fields object from the original run is the form of {key: value
    # } Hash which is not suitable format for the query statement
    # INPUT:
    # [{"key"=>"assignee", "value"=>{"id"=>"pruan"}},
    # {"key"=>"products", "value"=>{"id"=>"ocp"}},
    # {"key"=>"version", "value"=>{"id"=>"4_3"}},
    # {"key"=>"plannedin", "value"=>{"id"=>"OCP_4_3_Feature_Feeze"}},
    # {"key"=>"caseimportance", "value"=>{"EnumOptionId"=>[{"id"=>"critical"}, {"id"=>"high"}, {"id"=>"medium"}, {"id"=>"low"}]}},
    # {"key"=>"tags", "value"=>"ocp43ff13"},
    # {"key"=>"env_container_runtime", "value"=>{"id"=>"crio_1x"}},
    # {"key"=>"env_install_method", "value"=>{"id"=>"ipi"}},
    # {"key"=>"env_iaas_cloud_provider", "value"=>{"id"=>"azure"}},
    # {"key"=>"env_registry_storage_type", "value"=>{"id"=>"s3"}},
    # {"key"=>"subteam", "value"=>{"EnumOptionId"=>{"id"=>"metering"}}},
    # {"key"=>"caseautomation", "value"=>{"EnumOptionId"=>[{"id"=>"manualonly"}, {"id"=>"notautomated"}]}},
    # {"key"=>"env_network_backend", "value"=>{"id"=>"openshift-sdn"}},
    # {"key"=>"env_cluster", "value"=>{"EnumOptionId"=>{"id"=>"ocp_cluster"}}}]
    #
    # OUTPUT:
    # {"assignee"=>"pruan",
    #  "products"=>"ocp",
    #  "version"=>"4_3",
    #  "plannedin"=>"OCP_4_3_Feature_Feeze",
    #  "caseimportance"=>["critical", "high", "medium", "low"],
    #  "tags"=>"ocp43ff13",
    #  "env_container_runtime"=>"crio_1x",
    #  "env_install_method"=>"ipi",
    #  "env_iaas_cloud_provider"=>"azure",
    #  "env_registry_storage_type"=>"s3",
    #  "subteam"=>"metering",
    #  "caseautomation"=>["manualonly", "notautomated"],
    #  "env_network_backend"=>"openshift-sdn",
    #  "env_cluster"=>"ocp_cluster"}
    # given a query_result Custom object (Array).
    # @return Hash to be constructed
    def transform_custom_fields(src)
      custom_fields = {}
      src.each do |row_data|
        if row_data['value'].is_a? Hash
          if row_data['value'].has_key? 'EnumOptionId'
            if row_data['value']['EnumOptionId'].is_a? Hash
              value = row_data['value']['EnumOptionId']['id']
            else
              value = row_data['value']['EnumOptionId'].map {|r| r['id'] }
            end
          else
            value = row_data['value']['id']
          end
        else
          value = row_data['value']
        end
        # in case of nil, just force it to be empty string
        value ||= ""
        custom_fields[row_data['key']] = value
      end
      return custom_fields
    end

    # @input given a yaml, parse and extract the subcomopnent
    # @return String subcomponent name or nil
    def get_subcomponent(res_yaml)
      custom_list = res_yaml.dig('test_case', 'customFields', 'Custom')
      res = custom_list.select { |e| e.dig('value', 'id') if e.dig('key') == 'subteam' }
      if res.count > 0
        res.first.dig('value', 'id')
      else
        nil
      end
    end

    # given a testrun_id, generate a query statement based on testcase IDs and custom fields
    # which is fed into create_run_smart method to generate the new polarion run
    # @options: is the cli options with
    #  options['case_status'] = the cases status to be clones if none is given
    #  then we clone all
    #     valid_statuses = ['Passed', 'Failed', 'Waiting', 'Running', 'Blocked']
    #  options['title'] = title of the run to be cloned, if none a default use
    #  be used.
    # cli example: ./polarshift.rb clone-run 20210525-1939 -s passed -t "kata passed clone"
    # The YAML basically contains 3 fields
    # 1.   "run_title":  "Clone of xyz run"
    # 2.   "case_query": "<SQL_STATEMENT>"
    # 3.   "custom_fields": <CONSTRUCTED_FROM_call_to_get_smart_run_method>
    def clone_run(test_run_id: nil, options: nil)
      template_hash = {}
      case_status = options.status
      run_title = options.title
      valid_statuses = ['Passed', 'Failed', 'Waiting', 'Running', 'Blocked']
      query_result = polarshift.get_run_smart(project, test_run_id, with_cases: 'full')
      if case_status
        case_status = case_status.downcase.capitalize
        raised "Invalid status given, only #{valid_statuses} are accepted" unless valid_statuses.include? case_status
        filtered_cases = query_result['records']["TestRecord"].select {|r| r['result'] == case_status}
        # user wants further filter by specifying subteam as as a single or
        # multiple subteam by putting them in a csv
        if opts[:subteam]
          subteams = opts[:subteam].split(',')
          target_cases = []
          filtered_cases.each do |fc|
            fc_subteam = get_subcomponent(fc)
            target_cases << fc if subteams.include? fc_subteam
          end
          filtered_cases = target_cases
        end
        tc_ids = filtered_cases.map {|c| c['test_case']['id']}
        run_title ||= "Clone of '#{case_status}' cases for #{test_run_id}"
      else
        tc_ids = extract_test_case_ids(query_result)
        run_title ||= "Clone of #{test_run_id}"
      end
      if query_result['customFields'].nil?
        # hard-code it to something
        custom_fields = { "caseimportance" => "critical", "description" => "" }
      else
        custom_fields = transform_custom_fields(query_result['customFields']['Custom'])
      end
      tc_str = tc_ids.join(" ")
      template_hash[:run_title] = run_title
      template_hash[:case_query] = "id:(#{tc_str})"
      template_hash[:custom_fields] = custom_fields
      pr = polarshift.create_run_smart(project_id: project, **template_hash)
      quoted_run_id = "'" + pr[:run_id] + "'"
      puts "Source run id '#{test_run_id}' cloned to new run id: #{HighLine.color(quoted_run_id, :bright_blue)}"
    end

  end
end

if __FILE__ == $0
  BushSlicer::PolarShiftCli.new.run
end
