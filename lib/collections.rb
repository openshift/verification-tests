require 'set'

# should not require 'common'

module BushSlicer
  # a collections module that can be included
  module CollectionsIncl
    # @param struc [Object] array, hash or object to be deeply freezed
    # @return [Object] the freezed object
    def deep_freeze(struc)
      struc.freeze
      if struc.kind_of? Hash
        struc.each do |k, v|
          # deep_freeze(k) # keys are freezed already by ruby
          deep_freeze(v)
        end
      elsif struc.respond_to? :each
        struc.each do |el|
          deep_freeze(el)
        end
      else
        # we don't know how to go deeper here
      end
      return struc
    end

    # @param hash [Hash] object to be worked on
    # @yield block to return new key/val pairs based on original values
    # @return modified hash
    def map_hash(hash)
      if hash.kind_of? Hash
        target = {}
        hash.keys.each do |k|
          new_k, new_v = yield [k, hash[k]]
          target[new_k] = new_v
        end
      else
        return hash # return the object itself to aid recursion
      end
      return target # return the object itself to aid recursion
    end

    # @return hash with same content but keys.to_sym
    def hash_symkeys(hash)
      # Hash[hash.collect {|k,v| [k.to_sym, v]}]
      map_hash(hash) { |k, v| [k.to_sym, v] }
    end

    # @param hash [Hash] object to be modified
    # @yield block to return new key/val pairs based on original values
    # @return modified hash
    def map_hash!(hash)
      if hash.kind_of? Hash
        hash.keys.each do |k|
          new_k, new_v = yield [k, hash.delete(k)]
          hash[new_k] = new_v
        end
      end
      return hash # return the object itself to aid recursion
    end

    # @return hash with same content but keys.to_sym
    def hash_symkeys!(hash)
      map_hash!(hash) { |k, v| [k.to_sym, v] }
    end

    # @param hash [Hash] the hash to be modified
    # @yield block to return new key/val pairs based on original values
    def deep_map_hash!(hash)
      map_hash!(hash) { |k, v|
        new_k, new_v = yield [k, v]
        [new_k, deep_map_hash!(new_v) { |nk, nv| yield [nk, nv] }]
      }
    end

    # @param hash [Hash] the hash to be mapped
    # @yield block to return new key/val pairs based on original values
    def deep_map_hash(hash)
      map_hash(hash) { |k, v|
        new_k, new_v = yield [k, v]
        [new_k, deep_map_hash(new_v) { |nk, nv| yield [nk, nv] }]
      }
    end

    # @return [Hash] a new hash identical to original one except all keys are
    #  nstances of [String]
    def deep_hash_strkeys(hash)
      deep_map_hash(hash) do |k, v|
        [k.to_s, v]
      end
    end

    # @return [Hash] a new hash identical to original one except all keys are
    #  nstances of [Symbol]
    def deep_hash_symkeys(hash)
      deep_map_hash(hash) do |k, v|
        [k.to_sym, v]
      end
    end

    # @param base_hash [Hash] it is base or lower prio hash
    # @param override_hash [Hash] hash with values that override base_hash
    #   values
    # @return [Hash] the base_hash with new values and values overrides of the
    #   override_hash
    # @note this one does not merge Arrays
    def deep_merge(base_hash, override_hash)
      base_hash.merge(override_hash) { |key, oldval, newval|
        if oldval.kind_of?(Hash) && newval.kind_of?(Hash)
          deep_merge(oldval, newval)
        else
          newval
        end
      }
    end

    # @param tgt_hash [Hash] target hash that we will be **altering**
    # @param src_hash [Hash] read from this source hash
    # @return the modified target hash
    # @note this one does not merge Arrays; additionally when you have same
    #   Hash object in multiple parts of the tree, when merging on one part of
    #   the tree it will end up having same modification on the others
    def deep_merge!(tgt_hash, src_hash)
      tgt_hash.merge!(src_hash) { |key, oldval, newval|
        if oldval.kind_of?(Hash) && newval.kind_of?(Hash)
          deep_merge!(oldval, newval)
        else
          newval
        end
      }
    end

    # @param hash [Hash] the Hash object to slice
    # @param keys [Array] the keys we care about in the hash
    # @return [Hash] the resulting hash
    # @see active_support/core_ext/hash/slice.rb
    def hash_slice(hash, keys)
      hash.select { |k, v| keys.include? k }
    end

    # Method to covert Cucumber `Table#raw` into a hash
    # @param [Hash|Array] opts normalized Hash or raw array of String options
    # @param [Boolean] sym_mode if true, all keys are converted to Symbols
    # @param [Boolean] array_mode output is a two-dimentional array, not a Hash
    # @return unmodified hash or 2 dimentional array converted to a hash where
    #   multiple instances of same key are converted to `key => [value1, ...]`
    #   and keys starting with `:` are converted to Symbols
    # @note using this method may reorder options when multiple time same
    #   parameter is found; also when key is empty, the value is assumed a
    #   multi-line value
    def opts_array_to_hash(opts, sym_mode: true, array_mode: false)
      case opts
      when Hash
        # we assume that things are normalized when Hash is passed in
        return opts
      when Array
        if opts[0] && opts[0].size != 2
          # we accept empty opts array or array of two element arrays
          raise 'only array of two-values arrays is supported'
        end
        res = array_mode ? [] : {}
        lastval = nil
        opts.each do |key, value|
          key.strip!

          case key
          when ""
            if lastval
              # value modified in-place
              lastval << "\n" << value
              next
            else
              raise "cannot start table with an empty key"
            end
          when /^:/
            key = str_to_sym(key)
          end

          # convert keys to Symbol when in sym_mode
          key = str_to_sym(key) if sym_mode

          lastval = value
          if array_mode
            res << [key, value]
          else
            res[key] = res.has_key?(key) ? [res[key], value].flatten(1) : value
          end
        end

        return res
      else
        raise "unknown options format"
      end
    end
    def opts_array_process(opts, sym_mode: true, array_mode: true)
      opts_array_to_hash(opts, sym_mode: sym_mode, array_mode: array_mode)
    end

    # @param test_hash [Hash] the hash supposed to be a subhash
    # @param base_hash [Hash] the hash supposed to contain test_hash
    # @param failpath [Array, nil] if user supplies an array to this parameter
    #   it will be filled with the failure path in case test fails
    # @param null_deletes_key [Boolean] require null keys in test_hash to
    #   correspond to missing keys in base_hash
    # @param vague_nulls [Boolean] should we allow empty arrays and hashes be
    #   treated as equivalent to null values
    # @param exact_arrays [Boolean] should we look for array exact matches or
    #   subset; note: when false and there is order dismatch, false result is
    #   possible even if the struct is a subset
    # @return [Boolean]
    # @note: see `Scenario: substructs` in features/test/collections.feature for
    #   tests
    def substruct?(test_hash, base_hash, failpath: nil, null_deletes_key: false,
                 vague_nulls: false, exact_arrays: false)

      recurse = proc { |k, v|
        success = substruct?(
            v, base_hash[k],
            failpath: failpath,
            null_deletes_key: null_deletes_key,
            vague_nulls: vague_nulls,
            exact_arrays: exact_arrays
          )
        failpath.unshift(k) if failpath && !success
        success
      }

      only_nulls = proc { |h|
        return h.nil? ||
          ( Hash === h && h.all? {|k,v| only_nulls === v} ) # ||
          # ( Array === h && h.all? {|e| only_nulls === e} )
      }

      case
      when Hash === test_hash && Hash === base_hash
        return test_hash.all? { |k,v|
          if v.nil? && null_deletes_key
            !base_hash.has_key?(k)
          else
            base_hash.has_key?(k) && recurse.call(k, v)
          end
        }
      when Array === test_hash && Array === base_hash
        return exact_arrays && test_hash.size == base_hash.size &&
          test_hash == base_hash ||
          # test_hash.each_with_index.all? { |v,k| recurse.call(k, v) } ||

          !exact_arrays && test_hash.size <= base_hash.size &&
          test_hash.reduce({success: true, basearry: base_hash.dup}) { |memo, v|
            if e = memo[:basearry].find {|e| recurse.call(base_hash.find_index(e), v)}
              memo[:basearry].delete(e)
              memo
            else
              memo[:success] = false
              break memo
            end
          }[:success]
      when test_hash.nil?
        return base_hash.nil? ||
          vague_nulls && Enumerable === base_hash && base_hash.empty?
      when base_hash.nil?
        return vague_nulls && null_deletes_key && only_nulls === test_hash
      else
        return test_hash == base_hash
      end
    end

    # helper method to get variables hash from a Cucumber Table#raw
    # @param opts [Hash, Array<String>] array of strings like `VAR=VALUE` pairs
    #   or a Hash; if Hash, no processing is done
    # @return [Hash<String, String>] a hash suitable to set env variables
    def to_env_hash(opts)
      opts = [ opts ] if opts.kind_of?(String)

      case opts
      when Hash
        return opts
      when Array
        res = {}
        opts.each do |str|
          var, val = str.split('=', 2)
          raise "wrong variable assignment: #{str.inspect}" unless val
          res[var] = val
        end
        return res
      else
        raise "unknown environment format: #{opts.inspect}"
      end
    end
  end

  # a module to call the methods directly on
  module Collections
    extend CollectionsIncl
  end

  # a hacked Hash that will track all accessed keys from base_hash
  #class UsageTrackingHash < Hash
  #  def initialize(base_hash)
  #    @base_hash = base_hash
  #    super do |hash, key|
  #      if @base_hash.has_key? key
  #        self[key] = @base_hash[key]
  #      else
  #        nil
  #      end
  #    end
  #  end
  #
  #  def not_accessed_keys
  #    return keys - @base_hash.keys
  #  end
  #end

  # hash like object to that will track all accessed keys from base_hash
  class UsageTrackingHash
    def initialize(base_hash)
      @base_hash = base_hash
      @accessed_keys = Set.new
    end

    def [](k)
      if @base_hash.has_key?(k)
        @accessed_keys << k
        return @base_hash[k]
      else
        return nil
      end
    end

    def has_key?(key)
      return @base_hash.has_key?(key)
    end

    def keys
      @base_hash.keys
    end

    def not_accessed_keys
      return @base_hash.keys - @accessed_keys.to_a
    end
  end
end
