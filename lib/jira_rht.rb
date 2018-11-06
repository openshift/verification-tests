# support library for using RHT JIRA
lib_path = File.expand_path(File.dirname(__FILE__))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
  $LOAD_PATH.unshift(lib_path)
end
require 'jira-ruby'
require 'common'

module BushSlicer
  class Jira
    include Common::Helper

    def initialize(options={})
      raise "No default options detected, please makse sure the PRIVATE_REPO \
      is cloned into your repo or ENV BUSHSLICER_PRIVATE_DIR is defined" if default_opts.nil?
      @options = default_opts.merge options
      ## try to obtain user/password in all possible ways
      @options[:username] = ENV['JIRA_USER'] if ENV['JIRA_USER']
      @options[:password] = ENV['JIRA_PASSWORD'] if ENV['JIRA_PASSWORD']
      unless @options[:username]
        Timeout::timeout(120) {
          STDERR.puts "JIRA user (timeout in 2 minutes): "
          @options[:username] = STDIN.gets.chomp
        }
      end
      unless @options[:password]
        STDERR.puts "JIRA Password: "
        @options[:password] = STDIN.noecho(&:gets).chomp
      end
      ## set logger
      @logger = @options[:logger] || logger
      raise "specify JIRA user and password" unless @options[:username] && @options[:password] && !@options[:username].empty? && !@options[:password].empty?
    end

    def client
      return @client if @client
      options = @options.dup
      options[:read_timeout] ||= 30
      options[:use_ssl] ||= true
      options[:ca_path] = expand_private_path(options[:ca_path], public_safe: true) if options[:ca_path]
      options[:ca_file] = expand_private_path(options[:ca_file], public_safe: true) if options[:ca_file]

      @client = JIRA::Client.new(options)
    end

    # @id is the identifier for the project, can be either an Integer or Name string
    def project(id: nil)
      if id.nil?
        return client.Project.find(self.client.options[:project])
      else
        # id is set, ignore reload status
        begin
          return client.Project.find(id)
        rescue => e
          @logger.error("Can't find project '#{id}', exiting...\n #{e}")
          exit
        end
      end
    end

    ## XXX not sure if a regular user can delete issues
    def delete_issue(issue_id)
      issue = client.Issue.find(issue_id)
      if issue.delete
        @logger.info("Issue #{issue_id} deleted successfully")
      else
        @logger.info("Failed to delete issue #{issue_id}")
      end
    end

    # @params is a hash of paramters to be created for the JIRA issue.
    # returns the save status & the issue object
    def create_issue(params)
      issue = client.Issue.build
      status = issue.save("fields"=>params)
      # call fetch to update the issue object
      @logger.error("Failed to create JIRA issue") unless status
      issue.fetch if status
      return status, issue
    end

    # @params is a hash containing: assignee, and testrun id in the summary
    # returns an array of matching JIRA issue, empty array otherwise.
    def find_issue_by_testrun_id(query_params)
      query = "(assignee = #{query_params[:assignee]}) AND (summary ~ run:#{query_params[:run_id]})"
      res = client.Issue.jql(query)
      return res
    end

    def get_all_project_issues(proj_id: nil)
      proj = project(id: proj_id)
      return proj.issues
    end

    def get_all_project_issuetypes(proj_id: nil)
      proj = project(id: proj_id)
      return proj.issuetypes
    end

    def get_default_issuetype
      issue_type = @options[:issue_type]
      issuetypes = get_all_project_issuetypes
      return issuetypes.select {|i| i.attrs if issue_type == i.name}[0]
    end

    # @id, id could either be Integer or String
    # returns a component object
    def get_component(id)
      # Automation component has id of 11173
      return client.Component.find(id)
    end

    # @comps is an array of component names from your project i.e. ['Automation', 'SVT']
    # if empty, then we just get that from the config
    def get_default_components(comps=[])
      comps = @options[:components] if comps.count == 0
      all_comps = get_components
      return all_comps.select {|c| c.attrs if comps.include? (c.name)}
    end
    # returns all components for the a project
    def get_components(project_id=nil)
      return self.project.components if project_id.nil?
      project = client.Project.find(project_id)
      return project.components
    end

    # constuct a text str that will appear as hyperlink under JIRA
    def make_link(url, text)
      return ("[#{text}|#{url}]")
    end

    def get_user(user_name)
      user = nil
      begin
        user = client.User.find(user_name)
      rescue => e
        @logger.error("Error: #{e.to_s}")
      end
    end

    def default_opts
      return  conf[:services, :jira]
    end

    def finalize
    end
  end
end

module JIRA
  class HttpClient
    old_http_client = instance_method(:http_conn)
    define_method(:http_conn) do |url|
      h = old_http_client.bind(self).(url)
      h.ca_path = @options[:ca_path] if @options[:ca_path]
      h.ca_file = @options[:ca_file] if @options[:ca_file]
      return h
    end
  end
end
