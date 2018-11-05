require_relative 'limit_range_constraint'

module BushSlicer
  # https://docs.openshift.com/online/rest_api/api/v1.LimitRange.html
  class LimitRangeItem
    include Common::BaseHelper

    attr_reader :raw
    private :raw

    def initialize(spec)
      @raw = spec.freeze
    end

    def type
      raw["type"]
    end

    def max_limit_request_ratio
      raw["maxLimitRequestRatio"]
    end

    # methods for all possible contstraints defined within this item
    ["default", "defaultRequest", "max", "min"].each do |constraint|
      define_method(Common::BaseHelperStatic.
                    camel_to_snake_case(constraint).to_sym) do
        if instance_variable_defined?("@#{constraint}".to_sym)
          instance_variable_get("@#{constraint}".to_sym)
        else
          instance_variable_set("@#{constraint}".to_sym,
                                LimitRangeConstraint.new(raw[constraint]))
        end
      end
    end

    # check item is of type matching value
    # @param value [String, Class]
    def ===(value)
      case value
      when Class
        value.to_s.downcase.end_with? type.downcase
      when String
        value.downcase == type.downcase
      else
        raise ArgumentError, "don't know how to compare LimitRangeItem type" \
         " with #{value.class}"
      end
    end
  end
end
