require 'find'
# require 'shellwords'

require 'collections'
require 'rules_common.rb'

module VerificationTests
  class RulesCommandExecutor
    # include VerificationTests::Common::Helper

    attr_reader :host

    # @param [Object] rules might be parsed rules, file, directory or array of any of these. All rules are merged and error is raised on duplicate rules. If directory string ends with slash `/` character, then it is loaded recursively.
    # @param [VerificationTests::Host] host host to execute the commands on
    # @param [String] user host os user to execute command as (e.g. sudo)
    def initialize(host:, user: nil, rules:)
      @host = host
      @user = user
      @rules_source = rules
    end

    # run cli command based on rules
    #   rules in YAML would look like:
    #   :global_options:
    #     :login: --rhlogin <value>
    #     :password: -p '<value>'
    #   :domain_create:
    #     :cmd: rhc domain create <domain_name>
    #     :options:
    #       :force: --force
    #       :some_opt: --some_opt <value>
    #     :expected:
    #     - Deleting domain '<domain_name>'
    #     - !ruby/regexp '/deleted/i'
    #     :unexpected:
    #     - Domain <domain_name> not found
    #     :properties:
    #       :url: !ruby/regexp '/URL:\s*(\S+)$/i'
    #     :optional_properties:
    #       :teliid_user: !ruby/regexp '/Teiid User:\s(\S+)$/i'
    #   `:global_options` are options common to all commands
    #   `:domain_create` is the command key
    #   `:expected` is strings in output that should match on success
    #   `:unexpected` is strings in the output showing command failure
    #   `:properties` are parsed proparties from the command output returned
    #   `:optional_properties` same as above but will not cause fail if missing
    # @return [VerificationTests::ResultHash] result hash
    # @see #build_command_line
    # @see #build_expectations
    # @see #process_result
    def run(cmd_key, options)
      cmd_options, exec_options = self.class.split_exec_options(options)
      cmd = build_command_line(cmd_key, cmd_options)
      res = host.exec_as(@user, cmd, stderr: :stderr, **exec_options)

      rules_execution_result_processor = proc {
        process_result(result: res, rules: rules[cmd_key], options: cmd_options)
      }

      if exec_options[:background]
        # insert a proc into res that can be called after command completion
        #   if regular command result processing is desired by user
        res[:rules_result_processor] = rules_execution_result_processor
      else
        # for foreground execution process command result right away
        rules_execution_result_processor.call
      end
      # add the :parsed automatically if a user specify the output option in
      # the the command line
      fmt = nil
      cmd_options.each do | k, v |
        fmt = v if [:output, :o].include? k
      end
      # JSON is subset of YAML, so we cna just use YAML parser to address both
      if res[:success] && ['json', 'yaml'].include?(fmt)
        res[:parsed] = YAML.load(res[:stdout])
      end

      return res
    end

    # splits command options from host exec options
    # @param options [Hash, Array] options provided by user
    # @return [Array<Array, Hash>] the split options [cmd_options, exec_options]
    def self.split_exec_options(options)
      cmd_options = []
      exec_options = {}
      options.each do |k, v|
        if k.to_s.start_with? "_"
          exec_options[k[1..-1].to_sym] = v
        else
          cmd_options << [ k, v ]
        end
      end

      if exec_options[:env]
        # env is likely incorrect format if derived from a Cucumber table
        exec_options[:env] = Collections.to_env_hash exec_options[:env]
      end

      return [ cmd_options, exec_options ]
    end

    # substitute options inside expected/unexpected patterns;
    #   if option is not found, we do not fail here
    def build_expectations(cmd_rules, options)
      expected = cmd_rules[:expected] || []
      unexpected = cmd_rules[:unexpected] || []
      expected = expected.dup
      unexpected = unexpected.dup

      # replace only things that look like opt keys
      gsub = proc do |str|
        str.gsub(/<([a-z_]+?)>/) { |m|
          key = m[1..-2].to_sym
          val = nil
          if options.kind_of?(Hash)
            val = options[key]
          else
            options.each{ |k,v|
              if k == key
                if val
                  raise "cannot handle multiple opts for expectations building"
                else
                  val = v
                end
              end
            }
          end
          val ? normalize(val, :noescape => true) : m
        }
      end

      [expected, unexpected].each do |patterns|
        patterns.map! do |pattern|
          case pattern
          when String
            gsub.call(pattern)
          when Regexp
            # do some magic to gsub regular expressions
            changed = gsub.call(pattern.source)
            changed == pattern.source ? pattern : Regexp.new(changed)
          else
            raise "unsupported pattern type #{pattern.class}: #{pattern}"
          end
        end
      end

      return expected, unexpected
    end

    # process command execution result
    # @param [Hash] result the result to operate on
    # @param [Hash] rules the rules for particular command to use for processing
    # @param [options] options the options provided by user
    def process_result(result:, rules:, options:)
      success = result[:success]
      expected, unexpected = build_expectations(rules, options)

      # check expected output
      expected.delete_if { |pattern|
        if pattern.respond_to? :~
          pattern =~ result[:response]
        else
          result[:response].include? pattern
        end
      }
      result[:expected_missing] = expected unless expected.empty?

      # check unexpected output
      unexpected.select! { |pattern|
        if pattern.respond_to? :~
          pattern =~ result[:response]
        else
          result[:response].include? pattern
        end
      }
      result[:unexpected_present] = unexpected unless unexpected.empty?

      # alter status based on expectations
      success = success && expected.empty? && unexpected.empty?

      ## handle :properties
      result[:props] = {}
      get_props = proc { |prop_rules, optional|
        prop_rules.each { |key, pattern|
          match = pattern.match(result[:response])
          case
          when match.nil?
            success = false unless optional
            (result[:props_missing] ||= []) << key
          when match.size > 2
            raise "regexp can have at most one capturing group"
          when match.size == 2
            result[:props][key] = match[1]
          when match.size ==1
            result[:props][key] = match[0]
          else
            puts "Santa Claus Does Really Exist!"
          end
        }
      }
      get_props.call(rules[:properties] || [], false)
      get_props.call(rules[:optional_properties] || [], true)

      result[:success] = success
    end

    # @param [Symbol] cmd_key the command key to invoke
    # @param [Hash, Array] options the options for building the command line
    #       If it is array, expected is to have each element to be a 2 element
    #       Array itself where first element is option key and second
    #       is option value. If Hash, then option key is the hash key.
    #       When multiple arguments with same key are desired, then use an
    #       array of values or in case you provie and array - multiple lements
    #       with same option key.
    # @return [String] the built command
    # @note all commands are read from the rules. There is a special command
    #       :global_options that provides base rules for any other command.
    #       There are three special option values - :false, `literal: thing`
    #       and `noescape: thing`.
    #       :false means to avoid setting this option and `literal: :false`
    #       would translate to `:false` for the remote chance one needs to set
    #       literal `:false` as a string value. Basically everything after
    #       `literal:` will be threated like a literal string. `noescape: thing`
    #       will avoid shell escaping `thing`, but usage is discouraged.
    #       Multiple arguments from the same type are supported.
    #       Placeholders for options and global command options can be specified
    #       in :cmd with `<options>` and `<global_options>`.
    def build_command_line(cmd_key, options)
      global_option_rules = rules[:global_options] || {}
      raise "unknown command #{cmd_key}" unless rules[cmd_key]
      option_rules = rules[cmd_key][:options] || {}

      ## build command parameters based on cmd options
      #  if rules are missing for a user provided option, we raise
      parameters = ""
      global_parameters = ""
      cmd = rules[cmd_key][:cmd].dup
      cmd_used_options = [] # to control ignorant multiple values
      options.each { |key, values|
        [values].flatten.each { |value|
          # `false' might be valid option so we take it literal by default
          skip = ( value == ":false" || value == :false || value.nil? )

          case
          when option_rules[key]
            parameters << " " << option_rules[key].gsub('<value>') {normalize(value)} unless skip
          when global_option_rules[key]
            global_parameters << " " << global_option_rules[key].gsub('<value>') {normalize(value)} unless skip
          when cmd.include?("<#{key}>")
            if cmd_used_options.include? key
              raise "option '#{key}' allowed only once in #{cmd_key} command"
            else
              cmd.gsub!("<#{key}>") {skip ? "" : normalize(value)}
              cmd_used_options << key
            end
          else
            # unknown options are threated like errors to avoid false positives
            raise "no rules found for option: #{key}"
          end
        }
      }

      ## build final command
      #  we raise when mandatory options in :cmd are missing
      opts_added = globals_added = false
      cmd.gsub!(/<(.+?)>/) { |m|
        opt_key = m[1..-2].to_sym
        case opt_key
        when :options
          opts_added = true
          parameters
        when :global_options
          globals_added = true
          global_parameters
        else
          # cmd substitution is already performed in the previous loop
          # options[opt_key] || raise("need to provide '#{opt_key}' option")
          raise "required command option not supplied: #{opt_key}"
        end
      }

      cmd << parameters unless opts_added
      cmd << global_parameters unless globals_added
      return cmd
    end

    # convert value to normalized string
    # @param [#to_s] value value to normalize
    # @return [String] normalize value
    # @note imaplement {self#build_command_line} described handling of values
    def normalize(value, **opts)
      value = value.to_s
      noescape = opts.has_key?(:noescape) ? opts[:noescape] : false
      catch(:redo) do
        case value
        when /\Aliteral: (.*)\z/
          value = $1
        when /\Anoescape: (.*)\z/
          value = $1
          noescape = true
          redo
        end
      end
      value = host.shell_escape value unless noescape
      return value
    end

    private def rules
      return @rules if @rules
      rules = Collections.deep_freeze(Common::Rules.load(@rules_source))
      self.class.validate_rules(rules)
      return @rules = rules
    end

    def self.validate_rules(rules)
      # TODO: raise if we find duplicate keys used in :cmd and :options as well in :global_options
    end

    def clean_up
      # I don't see what we can do here, not safe to clean_up host
    end
  end
end
