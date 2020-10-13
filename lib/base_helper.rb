# should not require 'common'
# should only include helpers that do NOT load any other BushSlicer classes
require 'securerandom'
require 'find'
require 'pathname'

module BushSlicer
  module Common
    module BaseHelper
      def to_bool(param)
        return false unless param
        if param.kind_of? String
          return !!param.downcase.match(/^(true|t|yes|y|on|[0-9]*[1-9][0-9]*)$/i)
        elsif param.respond_to? :empty?
          # true for non empty maps and arrays
          return ! param.empty?
        else
          # lets be more conservative here
          return !!param.to_s.downcase.match(/^(true|yes|on)$/)
        end
      end

      def word_to_num(which)
        if which =~ /first|default/
          return 0
        elsif which =~ /other|another|second/
          return 1
        elsif which =~ /third/
          return 2
        elsif which =~ /fourth/
          return 3
        elsif which =~ /fifth/
          return 4
        end
        raise "can't translate #{which} to a number"
      end

      # normalize strings used for keys
      # @param [String] key the key to be converted
      # @return string converted to a Symbol key
      def str_to_sym(key)
        return key if key.kind_of? Symbol
        return key.gsub(" ", "_").sub(/^:/,'').to_sym
      end

      def exception_to_string(e)
        str = "#{e.inspect}\n    #{e.backtrace.join("\n    ")}"
        e = e.cause
        while e do
          str << "\nCaused by: #{e.inspect}\n    #{e.backtrace.join("\n    ")}"
          e = e.cause
        end
        return str
      end

      def rand_str(length=8, compat=:nospace_sane)
        raise if length < 1

        result = ""
        array = []

        case compat
        when :dns
          #  matching regex [a-z0-9]([-a-z0-9]*[a-z0-9])?
          #  e.g. project name (up to 63 chars)
          for c in 'a'..'z' do array.push(c) end
          for n in '0'..'9' do array.push(n) end
          array << '-'

          result << array[rand(36)] # needs to start with non-hyphen
          (length - 2).times { result << array[rand(array.length)] }
          result << array[rand(36)] if length > 1# end with non-hyphen
        when :dns952
          # matching regex [a-z]([-a-z0-9]*[a-z0-9])?
          # e.g. service name (up to 24 chars)
          for c in 'a'..'z' do array.push(c) end
          for n in '0'..'9' do array.push(n) end
          array << '-'

          result << array[rand(26)] # start with letter
          (length - 2).times { result << array[rand(array.length)] }
          result << array[rand(36)] if length > 1# end with non-hyphen
        when :hex
          result = SecureRandom.hex(length)
        when :num
          result << "%0#{length}d" % rand(10 ** length)
        when :lowercase_num
          for c in 'a'..'z' do array.push(c) end
          for n in '0'..'9' do array.push(n) end
          (length - 1).times { result << array[rand(array.length)] }
        when :ruby_variable
          for c in 'a'..'z' do array.push(c) end
          array << "_"
          result << array[rand(array.length)] # begin with letter or underscore
          for c in 'A'..'Z' do array.push(c) end
          for n in '0'..'9' do array.push(n) end

          (length - 1).times { result << array[rand(array.length)] }
        else # :nospace_sane
          for c in 'a'..'z' do array.push(c) end
          for c in 'A'..'Z' do array.push(c) end
          for n in '0'..'9' do array.push(n) end

          # avoid hiphen in the beginning to not confuse cmdline
          result << array[rand(array.length)] # begin with non-hyphen
          array << '-' << '_'

          (length - 1).times { result << array[rand(array.length)] }
        end

        return result
      end

      # replace <something> strings inside strings given option hash with symbol
      #   keys
      # @param [String] str string to replace
      # @param [Hash] opts hash options to use for replacement
      def replace_angle_brackets!(str, opts)
        str.gsub!(/<(.+?)>/) { |m|
          opt_key = m[1..-2].to_sym
          opts[opt_key] || raise("need to provide '#{opt_key}' REST option")
        }
      end

      # platform independent way to get monotonic timer seconds
      def monotonic_seconds
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def capture_error
        return true, yield
      rescue => e
        return false, e
      end

      # repeats block until it returns true or timeout reached; timeout not
      #   strictly enforced, use other timeout techniques to avoid freeze
      # @param seconds [Numeric] the max number of seconds to try operation to
      #   succeed
      # @param interval [Numeric] the interval to wait between attempts
      # @param stats [Hash] collect stats
      # @param jitter_multiplier [Numeric] (value >= 1) used to generate
      #   random jitter in the wait interval using the decorrelated jitter
      #   algorithm from https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
      #   Jitter helps reduce contention between simultaneous clients
      # @yield block the block will be yielded until it returns true or timeout
      #   is reached
      def wait_for(seconds, interval: 1, stats: nil, jitter_multiplier: 3)
        if seconds.nil?
          seconds = 0
        end
        iterations = 0
        start = monotonic_seconds
        # pre-compute deadline
        deadline = start + seconds
        success = false
        base_interval = interval
        until monotonic_seconds > deadline
          (success = yield) and break
          # only print if we actually have to wait
          if iterations == 0
            Kernel.puts("waiting for operation up to #{seconds} seconds..")
          end
          if jitter_multiplier >= 1
            # remaining can't be negative
            jit = rand(base_interval...(jitter_multiplier * interval))
            # rand(1...1) can return nil
            if jit.nil?
              jit = 0
            end
            # cap max wait at seconds remaining (deadline - monotonic_seconds)
            # (deadline - monotonic_seconds) will be negative if we have expired since entering loop.
            interval = [(deadline - monotonic_seconds), jit].min
          end
          # timeout has expired since we entered this loop
          if interval <= 0
            break
          end
          sleep interval
          iterations += 1
        end

        return success

      ensure
        if stats
          stats[:seconds] = monotonic_seconds - start
          stats[:full_seconds] = stats[:seconds].to_i
          stats[:iterations] = iterations
        end
      end

      # converts known label selectors to a [Array<String>] for use with cli
      #   commands
      # @param labels [String, Array] labels to filter on; e.g. you can use
      #   like `selector_to_label_arr(*hash, *array, str1, str2)`
      # @return [Array<String>]
      # @note it is somehow confusing to call this method properly, examples:
      #   selector_to_label_arr(*hash_selector)
      #   selector_to_label_arr(*array_of_arrays_with_label_key_value_pairs)
      #   selector_to_label_arr(str_label1, str_label2, ...)
      #   selector_to_label_arr(*hash, str_label1, *arr1, arr2, ...) # first we
      #     have a Hash with label_key/label_value pairs, then a plain string
      #     label, then an array of arrays with one or two elements denoting
      #     label_key or label_key/label_value pairs and finally an array of
      #     with one or two elements denoting a label_key or a
      #     label_key/label_value pair
      def selector_to_label_arr(*sel)
        sel.map do |l|
          case l
          when String
            l
          when Array
            if l.size < 1 && l.size > 2
              raise "array parameters need to have 1 or 2 elements: #{l}"
            end

            if ! l[0].kind_of?(String) || (l[1] && ! l[1].kind_of?(String))
              raise "all label key value pairs passed should be strings: #{l}"
            end

            if l[0].include?('=') || (l[1] && l[1].include?('='))
              raise "only accept expanded label selector arrays, e.g. selector_to_label_arr(*arry); either that or your label request is plain wrong: key='#{l[0]}' val='#{l[1]}'"
            end

            str_l = l[0].to_s.dup
            str_l << "=" << l[1].to_s unless l[1].nil?
            str_l
          when Hash
            raise 'to pass hashes, expand them with star, e.g. `*hash`'
          else
            raise "cannot convert labels to string array: #{sel}"
          end
        end
      end

      # test if a stirng is a number or not
      # @return float of int equivalent if the val is a number otherwise return val unmodified
      def str_to_num(val)
        num = Integer(val) rescue nil
        num = Float(val) rescue nil unless num
        return num if num
        return val
      end

      # @return [Binding] a binding empty from local variables
      def self.clean_binding
        binding
      end

      # @return [Binding] a binding with local variables set from a hash
      def self.binding_from_hash(b = nil, vars)
        b ||= self.clean_binding
        vars.each do |k, v|
          b.local_variable_set k.to_sym, v
        end
        return b
      end

      def getenv(var_name, strip: true, empty_is_nil: true)
        v = ENV[var_name]
        if v.nil? || empty_is_nil && v.empty?
          return nil
        else
          v = v.strip if strip
          return v
        end
      end

      def last_second_of_month(time=nil)
        time ||= Time.now
        if time.month == 12
          next_month = 1
          target_year = time.year + 1
        else
          next_month = time.month + 1
          target_year = time.year
        end
        return (Time.new(target_year, next_month) - 1)
      end

      # supports only sane camel case strings
      def camel_to_snake_case(str)
        str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
          gsub(/([a-z])([A-Z])/, '\1_\2').
          downcase
      end

      def snake_to_camel_case(str, mode: :class)
        case mode
        when :class
          str.split('_').map(&:capitalize).join
        when :method
          str.split('_').inject { |m, p| m + p.capitalize }
        else
          raise "unknown mode #{mode.inspect}"
        end
      end

      def to_utf8(str)
        # error occurs only when combining string of different character sets
        # when characters in one are invalid within the other, e.g.
        # [["0xa0".to_i(16),"0xa1".to_i(16)].pack("c*"), "asd", "№"].join
        if str.encoding == Encoding::UTF_8
          str
        else
          str.encode('utf-8', :invalid => :replace, :undef => :replace)
        end
      end

      # handles floating point string input
      def convert_to_bytes(raw_str)
        parsed = raw_str.match(/\A((?:\d*)(\.)?(?:\d+))([a-zA-Z]*)\z/)
        number = parsed[2].nil? ? Integer(parsed[1]) : Float(parsed[1])
        unit = parsed[3]
        case unit
        when "", "b"
          return number
        when "Ki", "KiB"
          return number * 1024
        when "K", "k", "kb" "KB"
          return number * 1000
        when "Mi", "MiB"
          return number * 1024 * 1024
        when "M", "m", "MB", "mb"
          return number * 1000 * 1000
        when "Gi", "GiB"
          return number * 1024 * 1024 * 1024
        when "G", "g", "GB", "gb"
          return number * 1000 * 1000 * 1000
        else
          raise "unknown memory unit '#{unit}'"
        end
      end

      def convert_cpu(cpu_str)
        parsed = cpu_str.match(/\A(\d+)([a-zA-Z]*)\z/)
        number = Integer(parsed[1])
        unit = parsed[2]
        case unit
        when ""
          return number * 1000
        when "m"
          return number
        else
          raise "unknown cpu unit '#{unit}'"
        end
      end

      def find_follow(*paths)
        block_given? or return enum_for(__method__, *paths)

        link_cache = {}
        link_resolve = lambda { |path|
          # puts "++ link_resolve: #{path}" # trace
          if link_cache[path]
            return link_cache[path]
          else
            return link_cache[path] = Pathname.new(path).realpath.to_s
          end
        }
        # this lambda should cleanup `link_cache` from unnecessary entries
        link_cache_reset = lambda { |path|
          # puts "++ link_cache_reset: #{path}" # trace
          # puts link_cache.to_s # trace
          link_cache.select! do |k,v|
            path == k || k == "/" || path.start_with?(k + "/")
          end
          # puts link_cache.to_s # trace
        }
        link_is_recursive = lambda { |path|
          # puts "++ link_is_recursive: #{path}" # trace
          # the ckeck is useless if path is not a link but not our responsibility

          # we need to check full path for link cycles
          pn_initial = Pathname.new(path)
          unless pn_initial.absolute?
            # can we use `expand_path` here? Any issues with links?
            pn_initial = Pathname.new(File.join(Dir.pwd, path))
          end

          # clear unnecessary cache
          link_cache_reset.call(pn_initial.to_s)

          link_dst = link_resolve.call(pn_initial.to_s)

          pn_initial.ascend do |pn|
            if pn != pn_initial && link_dst == link_resolve.call(pn.to_s)
              return {:link => path, :dst => pn}
            end
          end

          return false
        }

        do_find = proc { |path|
          Find.find(path) do |path|
            if File.symlink?(path) && File.directory?(File.realpath(path))
              if path[-1] == "/"
                # probably hitting https://github.com/jruby/jruby/issues/1895
                yield(path.dup)
                Dir.new(path).each { |subpath|
                  do_find.call(path + subpath) unless [".", ".."].include?(subpath)
                }
              elsif is_recursive = link_is_recursive.call(path)
                raise "cannot handle recursive links: #{is_recursive[:link]} => #{is_recursive[:dst]}"
              else
                do_find.call(path + "/")
              end
            else
              yield(path)
            end
          end
        }

        while path = paths.shift
          do_find.call(path)
        end
      end


    end




    module BaseHelperStatic
      extend BaseHelper
    end
  end
end
