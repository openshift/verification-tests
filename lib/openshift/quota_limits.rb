module BushSlicer
  # helper to access qoota limit values for classes like
  #   AppliedClusterResourceQuota
  class QuotaLimits
    include Common::Helper

    # @param values [Hash] values of the quota
    def initialize(values)
      @memory_limit = values["limits.memory"]
      @storage_requests = values["requests.storage"]
      @cpu = values["cpu"]
    end

    def memory_limit_raw
      @memory_limit
    end

    def storage_requests_raw
      @storage_requests
    end

    def cpu
      @cpu
    end

    # returns numeric representation of memrory limit in bytes
    def memory_limit
      convert_to_bytes(memory_limit_raw) if memory_limit_raw
    end

    def storage_requests
      convert_to_bytes(storage_requests_raw) if storage_requests_raw
    end

    #def cpu_limit
    #  return convert_cpu(self.cpu_limit_raw)
    #end

    #def cpu_request
    #  return convert_cpu(self.cpu_request_raw)
    #end
  end
end
