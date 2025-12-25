require 'yaml'

module BushSlicer
  module Common
    module Rules
      def self.load(*sources)
        return sources.flatten.reduce({}) { |rules, source|
          if source.kind_of? Hash
          elsif File.file? source
            source = YAML.safe_load_file source, aliases: true, permitted_classes: [Symbol, Regexp]
          elsif File.directory? source
            files = []
            if source.end_with? "/"
              # we should be recursive
              Find.find(source) { |path|
                if File.file?(path) && path.end_with?(".yaml",".yml")
                  files << path
                end
              }
            else
              # we should only load .yaml files in current dir
              files << Dir.entries(source).select {|d| File.file?(d) && d.end_with?(".yaml",".yml")}
            end

            source = load(files)
          else
            raise "unknown rules source '#{source.class}': #{source}"
          end

          rules.merge!(source) { |key, v1, v2|
            raise "duplicate key '#{key}' in rules: #{sources}"
          }
        }
      end

      # merge opts from logged_users[user.name] and cli options given by user;
      #   opts might be a Hash or an array of key/value pairs;
      #   if `:config` key exists in opts, then it overrides base opts
      # @param base [{:config => String}] the user config option
      # @param opts [Hash, Array] the
      # @return [Array,Hash] depending on `opts` parameter type
      def self.merge_opts(base, opts)
        if opts.kind_of? Hash
          return base.merge opts
        elsif opts.kind_of? Array
          if opts.find {|k,v| k == :config}
            return opts.dup
          else
            return base.to_a.concat opts
          end
        end
        raise "don't know how to handle options type: #{opts.class}"
      end
    end
  end
end
