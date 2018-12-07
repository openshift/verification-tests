require 'yaml'

module VerificationTests
  module Platform
    class YAMLRestorableFile < RestorableFile
      def as_hash
        YAML.load raw
      end

      def merge!(yaml)
        case yaml
        when String
          yaml = YAML.load yaml
        when Hash
          # things are fine
        else
          raise ArgumentError, "unknown merge yaml merge data #{yaml.inspect}"
        end
        update(VerificationTests::Collections.deep_merge(as_hash, yaml).to_yaml)
      end
    end
  end
end
