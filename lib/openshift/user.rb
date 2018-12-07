require 'api_accessor'
require 'api_accessor_owner'
require 'login'
require 'subscription_plan'
require_relative 'project'

module VerificationTests
  # @note represents an OpenShift environment user account
  class User < ClusterResource
    include VerificationTests::APIAccessorOwner

    attr_accessor :auth_name, :password

    RESOURCE = "users"

    # @param token [String] auth bearer token in plain string format
    # @param env [VerificationTests::Environment] the test environment user belongs to
    # @return [User]
    def self.from_token(token, env:)
      api_accessor = APIAccessor.new(
        token: token,
        token_protected: true,
        env: env
      )

      user = User.from_api_object(env, api_accessor.get_self[:parsed])
      api_accessor.id = user.name
      user.add_api_accessor api_accessor
      return user
    end

    # @param env [VerificationTests::Environment] the test environment user belongs to
    # @param name [String] optional username as returned by `get user '~'
    # @param auth_name [String] the name used to auth to OpenShift
    # @param password [String] password
    # @return [User]
    def self.from_user_password(auth_name, password, env:)
      if auth_name.nil? || password.nil? || auth_name.empty? || password.empty?
        raise "auth username and password need to be provided"
      end

      token, expires = Login.new_token_by_password(
        user: auth_name,
        password: password,
        env: env
      )

      api_accessor = APIAccessor.new(
        token: token,
        token_protected: false,
        expires: expires,
        env: env
      )

      user = User.from_api_object(env, api_accessor.get_self[:parsed])
      user.password = password.freeze
      user.auth_name = auth_name.freeze
      api_accessor.id = user.name
      user.add_api_accessor api_accessor
      return user
    end

    def self.from_cert(cert, key, env:)
      api_accessor = APIAccessor.new(
        client_cert: cert,
        client_key: key,
        env: env
      )

      user = User.from_api_object(env, api_accessor.get_self[:parsed])
      api_accessor.id = user.name
      user.add_api_accessor api_accessor
      return user
    end

    def plan
      @plan ||= SubscriptionPlan.new(self)
    end

    # @return true if we know user's password
    def password?
      return !! @password
    end

    def to_s
      "#{name}@#{env.opts[:key]}"
    end

    def password
      if @password
        return @password
      else
        # most likely we initialized user with token only so we don't know pswd
        raise "user '#{name}' initialized without a password"
      end
    end

    def webconsole_executor
      # TODO: if has token or password
      env.webconsole_executor.executor(self)
    end

    def webconsole_exec(action, opts={})
      # TODO: if has token or password
      env.webconsole_executor.run_action(self, action, **opts)
    end

    def clean_projects
      logger.info "cleaning-up user #{name} projects"
      ## make sure we don't delete special projects due to wrong permissions
      #  also make sure we don't hit policy cache incoherence
      only_safe_projects = wait_for(30, interval: 5) {
        projects = projects()
        return if projects.empty?
        project_names = projects.map(&:name)
        (project_names & Project::SYSTEM_PROJECTS).empty?
      }
      unless only_safe_projects
        raise "system projects visible to user #{name}, clean-up too dangerous"
      end

      res = cli_exec(:delete, object_type: "projects", object_name_or_id: '--all')
      # we don't need to check exit status, but some time is needed before
      #   project deleted status propagates properly
      unless res[:response].include? "No resource"
        logger.info("waiting up to 30 seconds for user clean-up to take place")
        visible_projects = []
        success = wait_for(30) { (visible_projects = projects()).empty? }
        unless success
          logger.warn("user #{name} has visible projects after clean-up, beware: #{visible_projects.map(&:name)}")
        end
      end
    end

    def clean_up_on_load
      # keep project clean first as it can also catch policy cache incoherence
      # see https://bugzilla.redhat.com/show_bug.cgi?id=1337096
      clean_projects
    end

    # @return [Array<Project>]
    def projects
      Project.list(user: self, get_opts: {_quiet: true})
    end

    def clean_up
      clean_up_on_load
      # best effort remove any non-protected tokens
      cached_api_accessors.reverse_each do |accessor|
        accessor.clean_up
      end
    end

  end
end
