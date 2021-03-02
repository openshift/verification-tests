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
      config = YAML.load_file(config_file)
    end

    ## return full raw configuration
    def raw
      return @raw_config if @raw_config

      raw_configs = []
      @opts[:files].each { |f| raw_configs << load_file(f) }

      # merge config from environment if present
      if ENV["BUSHSLICER_CONFIG"] && !ENV["BUSHSLICER_CONFIG"].empty?
        raw_configs << YAML.load(ENV["BUSHSLICER_CONFIG"])
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

  class FlexyEnvVariable
    attr_reader :var_name

    def initialize(var_name)
      @var_name=var_name
    end
    def ==(other)
      self.class===other &&
        @var_name==other.var_name
    end
    def to_s
      ENV[@var_name]
    end
    
    alias :eql? :==
    alias :to_str :to_s
    alias :[]= :to_s
  end

  class FlexyEnvFile
    @@files = Hash.new
    attr_reader :var_name

    def initialize(var_name)
      @var_name=var_name
    end
    def ==(other)
      self.class===other && 
        @var_name==other.var_name
    end
    def to_s
      file=@@files[@var_name]
      if !file.nil? && !file.file?
        @@files.except!(@var_name)
        file=nil
      end
      if file.nil?
        e = ENV[@var_name]
        Tempfile.open("env_#{@var_name}_") do |f|
          f.write("#{e}") if !e.nil?
          @@files[@var_name]=f
        end
      end
      file.path
    end

    alias :eql? :==
    alias :to_str :to_s
    alias :[]= :to_s
  end
end
