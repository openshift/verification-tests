module VerificationTests
  # https://docs.openshift.com/online/rest_api/api/v1.LimitRange.html
  class LimitRangeConstraint
    include Common::BaseHelper

    attr_reader :raw
    private :raw

    def initialize(spec)
      @raw = spec.freeze
    end

    ["cpu", "memory", "storage"].each do |ctype|
      define_method("#{ctype}_raw".to_sym) do
        raw[ctype]
      end
    end

    def cpu
      convert_cpu(cpu_raw) if cpu_raw
    end

    def memory
      convert_to_bytes(memory_raw) if memory_raw
    end

    def storage
      convert_to_bytes(storage_raw) if storage_raw
    end

  end
end
