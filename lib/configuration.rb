require "base64"
require 'yaml'

require 'bushslicer'
require 'collections'
# should not require 'common'

module BushSlicer
  # @note bushslicer configuration logic
  class Configuration

    def initialize(opts = {})
      @opts = opts
      unless opts[:files]
        opts[:files] = []
        opts[:files] << File.expand_path("#{HOME}/config/config.yaml")
        [
          "/config/config.yaml",
          "/config.yaml"
        ].each { |priv_config|
          file = File.expand_path(BushSlicer::PRIVATE_DIR + priv_config)
          opts[:files] << file if File.exist?(file)
        }
      end
    end

    def load_file(config_file)
      config = YAML.safe_load_file(config_file, aliases: true, permitted_classes: [Symbol, Regexp])
    end

    ## return full raw configuration
    def raw
      return @raw_config if @raw_config

      raw_configs = []
      @opts[:files].each { |f| raw_configs << load_file(f) }

      # merge config from environment if present
      if ENV["BUSHSLICER_CONFIG"] && !ENV["BUSHSLICER_CONFIG"].strip.empty?
        raw_configs << YAML.safe_load(ENV["BUSHSLICER_CONFIG"], aliases: true, permitted_classes: [Symbol, Regexp])
      end

      # merge all config files
      # note: `deep_merge!` not appropriate because of YAML anchoring producing
      #   same Hash objects in different parts of the tree
      @raw_config = raw_configs.reduce { |res, c|
        Collections.deep_merge(res, c)
      }

      Collections.deep_map_hash!(@raw_config) { |k, v| [k.to_sym, v] }

      env_overrides(@raw_config)

      # make sure config is not accidentally broken
      Collections.deep_freeze(@raw_config)

      return @raw_config
    end

    # logic to overrige configuration from environment variables
    def env_overrides(conf)
      global_overrides = {
        debug_in_after_hook: "BUSHSLICER_DEBUG_AFTER_FAIL",
        debug_in_after_hook_always: "BUSHSLICER_DEBUG_AFTER_HOOK",
        debug_attacher_timeout: "BUSHSLICER_DEBUG_ATTACHER_TIMEOUT",
        debug_failed_steps: "BUSHSLICER_DEBUG_FAILSTEP",
        default_environment: "BUSHSLICER_DEFAULT_ENVIRONMENT"
      }

      # if envvariable is set, then override the value where "false" is false
      global_overrides.each { |o, var|
        if ENV.key? var
          conf[:global][o] = ENV[var] == "false" ? false : ENV[var]
        end
      }
    end

    # @return value of configuration options or nil if not found
    # @note if opts do not start with one of the recognized root options,
    #   then :global is assumed. The idea is to keep private options in the
    #   :private namespace to avoid unintentional information leaks.
    #   You usually call this for common options like:
    #   `conf[:debug_in_after_hook]`
    #   `conf[:private, :git_repo_ssh_key]
    #   Also safe and possible to use deeper paths in configuration but I'd
    #   discourage such usage as uglier to read:
    #   `conf[:private, :auth, :git, :default_ssh_key]`
    def [](*opts)
      opts = opts.map {|o| o.to_sym}
      root_options = [:global,
                      :private,
                      :environments,
                      :optional_classes,
                      :services]
      unless root_options.include? opts.first
        opts.unshift :global
      end

      # go over each opt path to get its value
      val = raw
      opts.all? {|o| val = val[o]}
      return val
    end
    alias dig []

    # instanciates optional class based on optional_classes configuration key
    def get_optional_class_instance(keyword)
      class_opts = self[:optional_classes, keyword.to_sym]
      require class_opts[:include_path] if class_opts[:include_path]
      return Object.const_get(class_opts[:class]).new(**class_opts[:opts])
    end
  end

  # We basically try to duck-type the behavior of a String
  # @note comparing the object to string only works one-directonal, i.e.
  #   from_env_obj <=> str works but not str <=> from_env_obj
  class FromEnvVariable
    include Comparable

    attr_reader :var_name

    # We don't create such classes, they are just unmarshalled by YAML
    # def initialize(var_name)
    #   @var_name=var_name
    # end

    def inspect
      "#<#{self.class.shortclass}:#{to_s}>"
    end

    def self.shortclass
      self.name.split("::").last
    end

    alias :to_str :to_s

    [
      :[], :==, :<=>, :b, :bytes, :byteslice, :chars, :chomp, :chop, :chr,
      :codepoints, :count, :crypt, :delete, :downcase, :dump, :each_byte,
      :each_char, :each_codepoint, :each_line, :empty?, :encode, :encoding,
      :end_with?, :getbyte, :gsub, :hash, :hex, :include?, :index, :insert,
      :intern, :length, :lines, :ljust, :lstrip, :match, :match?, :next,
      :oct, :ord, :partition, :prepend, :replace, :reverse, :rindex, :rjust,
      :rpartition, :rstrip, :scan, :scrub, :setbyte, :size, :slice, :split,
      :squeeze, :start_with?, :strip, :sub, :succ, :sum, :swapcase, :to_c,
      :to_f, :to_i, :to_r, :to_sym, :tr, :tr_s, :unpack, :unpack1, :upcase,
      :upto, :valid_encoding?
    ].each do |name|
      define_method(name) do |*args, &block|
        to_s.public_send name, *args, &block
      end
    end
  end

  class ConfigEnvVariable < FromEnvVariable
    def to_s
      ENV[@var_name]
    end
  end

  class ConfigEnvFile < FromEnvVariable
    def to_s
      if !(cache[:file] && File.file?(cache[:file].path))
        # file was never created or was deleted in the mean time

        content = ENV[@var_name]

        unless content
          raise "Environemnt variable #{@var_name} was not set."
        end

        Tempfile.open("env_#{@var_name}_") do |f|
          f.write(Base64.decode64 content)
          cache[:file] = f
        end
      end
      cache[:file].path
    end

    # we override this because YAML unmarshals the file without
    # calling a constructor. Then configuration freezes all values.
    # Thus we can't initialize anything before object is frozen.
    # That's why we initialize the cache Hash within here.
    def freeze
      cache
      super
    end

    private def cache
      @cache ||= {}
    end
  end
end
