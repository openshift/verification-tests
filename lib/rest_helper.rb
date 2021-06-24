require 'cucuhttp'
require 'json'
require 'yaml'

module BushSlicer
  module Rest
    module Helper
      include Common::Helper

      def populate_common(base_path, path, base_opts, opts)
        base_opts[:url] = base_opts.delete(:base_url) + base_path + path

        replace_angle_brackets!(base_opts[:url], opts)
        base_opts[:headers].each {|h,v| replace_angle_brackets!(v, opts)}

        if base_opts[:headers]["Content-Type"].include?("json") &&
            ( base_opts[:payload].kind_of?(Hash) ||
              base_opts[:payload].kind_of?(Array) )
          # YAML was a bad idea https://github.com/tenderlove/psych/issues/243
          #base_opts[:payload] = YAML.to_json(base_opts[:payload])
          base_opts[:payload] = base_opts[:payload].to_json
          #base_opts[:payload] = JSON.pretty_generate(base_opts[:payload])
        end
      end

      # executes rest request and yields block if given on success
      def perform_common(**http_opts)
        res =  Http.request(**http_opts)
        if res[:success]
          res[:props] = {}

          if res[:headers] && res[:headers]['content-type']
            content_type = res[:headers]['content-type'][0]
            case
            when content_type.include?('json')
              res[:parsed] = JSON.load(res[:response])
            when content_type.include?('yaml')
              res[:parsed] = YAML.load(res[:response])
            end
          end

          yield res if block_given?
        end
        return res
      end
    end
  end
end
