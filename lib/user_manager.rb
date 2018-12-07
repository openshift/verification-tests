require 'set'

require 'api_accessor'
require 'common'
require 'openshift/user'

module VerificationTests
  class UserManager
    include Common::Helper
    attr_reader :env, :opts

    def initialize(env, **opts)
      @env = env
      @opts = opts
      @users = []
    end

    # @param num [Integer] the index of user to return; this may allocate a new
    #   user or return an already allocated one; negative index can only return
    #   from allocated users but not encouraged to use negative index
    # @return [User]
    def [](num)
      raise 'should use a subclass with #{__method__} implemented'
    end

    def by_name(username)
      users_used.find {|u| u.name == username}
    end

    def prepare(spec=nil)
      if spec
        raise "#{self.class} does not support users specification; " +
          "most probably scenario is intended to be run with a specific " +
          "user manager"
      end
    end

    def clean_up
      used = users_used

      # warn user if any users are skipped in scenario (and avoid confusion)
      used.reject!.with_index { |u, i|
        if u.nil?
          logger.error "user #{i} not used but users with higher index used, please avoid that"
          true
        end
      }

      used.each(&:clean_up)
      used.clear
    end

    # @return [#each, #clear, #find] a set of users that supports #clear, #each
    #   and #find methods; [Array] and [Set] should do
    private def users_used
      raise 'should use a subclass with #{__method__} implemented'
    end

    # @return [User] bcreated based on specification
    private def user_from_spec(spec)
      case spec
      when Hash
        User.send(spec[:method], **spec[:params], env: env)
      when String
        if spec.size < 3 || !spec.include?(":")
          raise "invalid user specification #{spec.inspect}"
        elsif spec.start_with? ':'
          User.from_token(spec[1..-1], env: env)
        else
          username, colon,  password = spec.partition(":")
          User.from_user_password(username, password, env: env)
        end
      else
        raise "invalid user specification #{spec.inspect}"
      end
    end
  end

  class StaticUserManager < UserManager
    attr_reader :users_used

    private :users_used

    def initialize(env, **opts)
      super
      load_users
      # # @users_used = Set.new
      @users_used = []
    end

    def load_users
      # opts[:user_manager_users].split(",").each do |uspec|
      #   username, colon,  password = uspec.partition(":")
      #   @users << User.new(username, password, env, **opts)
      # end
      raise "no users specification" unless opts[:user_manager_users]
      @user_specs = opts[:user_manager_users].split(",")
      Collections.deep_freeze(@user_specs)
    end

    # @see UserManager#[]
    def [](num)
      if @users_used[num]
        return @users_used[num]
      elsif @user_specs[num]
        @users_used[num] = user_from_spec(@user_specs[num])
        @users_used[num].clean_up_on_load
        return @users_used[num]
      else
        raise "missing specification for user index #{num}"
      end
    end
  end

  # basically a user manager with static username mapping and no clean-up
  # to allow pre-upgrade resource creation and testing after env upgrade
  class UpgradeUserManager < UserManager
    attr_reader :users_used

    private :users_used

    def initialize(env, **opts)
      super
      clean_state
    end

    # prepare users for scenario based on scenario tags
    # @param spec [String] scenario @users tag
    def prepare(spec=nil)
      unless spec && !spec.empty?
        raise "#{self.class} requires @users tag to be specified"
      end

      @user_specs = spec.split(",").map do |user_symbolic_name|
        if user_symbolic_name.empty?
          raise "empty user specification does not make sense"
        elsif env.static_user(user_symbolic_name)
          env.static_user(user_symbolic_name)
        else
          raise "static user '#{user_symbolic_name}' not configured in " +
            "'#{env.key}' environment"
        end
      end
      Collections.deep_freeze(@user_specs)
    end

    # @see UserManager#[]
    def [](num)
      if @users_used[num]
        return @users_used[num]
      elsif @user_specs[num]
        @users_used[num] = user_from_spec(@user_specs[num])
        # intentionally no clean-up on load for upgrade users
        return @users_used[num]
      else
        raise "no specification for user index #{num} in a scenario @users tag"
      end
    end

    def clean_state
      # clear state without actual OpenShift resource clean-up
      @users_used = []
      @user_specs = []
    end
    alias clean_up clean_state
  end

  # user manager to reserve users from an OwnThat app pool
  class PoolUserManager < UserManager
    attr_reader :pool

    private :pool

    def initialize(env, **opts)
      super
      unless opts[:user_manager_users]
        raise "you need to specify a user pool to reserve user from"
      end

      @pool = opts[:user_manager_users].match(/^(?:pool:)?(.+)$/)[1]
      if @pool.empty?
        raise "user pool should not be empty"
      end

      @users_used_raw = []
    end

    private def users_used
      @users_used_raw.map {|u| u ? u[:user] : nil}
    end

    private def ownthat
      @ownthat ||= OwnThat.new
    end

    # @see UserManager#[]
    def [](num)
      unless users_used[num]
        res = reserve_a_user
        @users_used_raw[num] = {lock: res}
        @users_used_raw[num][:user] = user_from_spec(res["resource"])
      end
      return users_used[num]
    end

    private def reserve_a_user
      res = ownthat.reserve_from_pool(env.api_endpoint_url, pool, "2h")
      return res || raise("User Pool #{pool} exhausted.")
    end

    private def release_users
      @users_used_raw.each do |user|
        lock = user[:lock]
        ownthat.release(lock["namespace"], lock["resource"], lock["owner"])
      end

      @users_used_raw.clear
    end

    def clean_up
      super
      release_users
    end
  end
end
