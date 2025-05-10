require 'yaml'
require 'find'

require 'collections'
require 'common'
require 'rules_common'
require_relative 'web4cucumber'

module BushSlicer
  class WebConsoleExecutor
    include Common::Helper

    attr_reader :env

    # if we need multiple rules version for ose/online/origin/etc, we can
    #   set a configuration option to read rules from different subdirs
    RULES_DIR = File.expand_path(HOME + "/lib/rules/web/console") + "/"
    SNIPPETS_DIR = HOME + "/lib/rules/web/snippets/"

    def initialize(env, **opts)
      @env = env
      @opts = opts
      @executors = {}
      @rules = nil # use rules cache to spare a few milliseconds
      @version = nil # cache rules version
    end

    def executor(user)
      return @executors[user.name] if @executors[user.name]

      browser_opts = @browser_opts || {
        logger: logger,
        base_url: env.web_console_url,
        browser_type: conf[:browser] ? conf[:browser].to_sym : :firefox,
        selenium_url: conf[:selenium_url],
        rules: RULES_DIR +  "base/", # will be updated after version is found
        snippets_dir: SNIPPETS_DIR,
        http_proxy: env.client_proxy
      }
      logger.debug "initializing web console browser for user #{user.name}"
      e = @executors[user.name] = Web4Cucumber.new(**browser_opts)

      unless @browser_opts
        # we didn't yet figure out versioned rules and browser opts
        versioned_rules = "#{RULES_DIR}#{get_master_version(user)}/"
        browser_opts_overrides_file = "#{versioned_rules}browser_opts.yml"

        logger.debug "adding versioned web console browser rules from " \
                     "'#{versioned_rules}'"
        e.replace_rules([e.rules, versioned_rules])
        browser_opts[:rules] = Collections.deep_freeze(e.rules)

        if e.started?
          # it seems we used browser to get cluster version, tag it as new here
          res = logout(user)
          @version_browser = e
          unless res[:success]
            raise  "logout from web console failed:\n" + res[:response]
          end
        end

        if File.exist? browser_opts_overrides_file
          logger.debug "recreating web console browser for user #{user.name}" \
                       "using overrides from '#{browser_opts_overrides_file}'"
          browser_opts_overrides = YAML.safe_load_file browser_opts_overrides_file, aliases: true, permitted_classes: [Symbol, Regexp]
          browser_opts.merge! browser_opts_overrides
          e.finalize
          e = @executors[user.name] = Web4Cucumber.new(**browser_opts)
        end

        @browser_opts = browser_opts
      end

      return e
    end

    def get_master_version(user, via_rest: true)
      if via_rest
        @version, major, minor = env.get_version(user: user)
        # for version like 3.y.z, lookup 3.y
        # for version like 4.y.z, lookup 4.y
        return [major, minor].join('.')
      else
        res = login(user)
        unless res[:success]
          raise "can not login via web console:\n" + res[:response]
        end

        res = executor(user).run_action(:get_master_version_from_webconsole)
        unless res[:success]
          raise "can not get the specific rule version:\n" + res[:response]
        end

        @version = executor(user).text.scan(/^OpenShift Master:\nv(.+)/)[0][0]
        # CliExecutor::rules_version
        v = @version.split('.')
        if v.first == '3' && v[1..2].all? {|e| e =~ /^[0-9]+$/} && v[3]
          # version like v3.0.0.0-32-g3ae1d27, i.e. return version 0
          return v[1]
        else
          # version like v1.0.2, i.e. return version 0
          return v[1]
        end
      end
    end

    def login(user)
      if user.password?
        return executor(user).run_action(:login,
                                         username: user.name,
                                         password: user.password)
      else
        # looks like we use token only user, lets try to hack our way in
        # res = user.get_self
        # if res[:success]
        return executor(user).run_action(:login_token,
                                           # user: res[:response].chomp,
                                           token: user.cached_tokens.first
                                          )
        # else
        #  raise "error getting user API object: res[:response]"
        # end
      end
    end

    def logout(user)
      if user.password?
        return executor(user).run_action(:logout)
      else
        return executor(user).run_action(:logout_forget)
      end
    end

    def run_action(user, action, **opts)
      login_actions = [ :login, :login_token ]

      if action == :logout && !user.password?
        return logout(user)
      end

      if !opts.delete(:_nologin)
        # login automatically on first use unless `_nologin` option given
        if is_new?(executor(user)) && !login_actions.include?(action)
          reset_new_status_of_version_browser(executor(user))
          res = login(user)
          unless res[:success]
            logger.error "login to web console failed:\n" + res[:response]
            return res
          end
        end
      end

      # execute actual action requested
      return executor(user).run_action(action, **opts)
    end

    def is_new?(browser)
      return !browser.started? || @version_browser == browser
    end

    def reset_new_status_of_version_browser(browser)
      @version_browser = nil if @version_browser == browser
    end

    def clean_up
      @executors.values.each(&:finalize)
      @executors.clear
    end

    def set_executor_for_user(user, executor)
      @executors[user.name] = executor
    end
  end
end
