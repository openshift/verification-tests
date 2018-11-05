
module BushSlicer
  # just a placeholder to define what a result hash means
  #   A ResultHash should contain at least the following keys:
  #   * :success       # true/false value showing if operation succeeded
  #   * :instruction   # human readable shor description of instruction issued
  #   * :response      # output from command or server response
  #   * :exitstatus    # numeric exit status from operation
  #   Some optional keys:
  #   * props          # some optional properties obtained from the operation
  #   * error          # error that caused operation failure
  class ResultHash < Hash
    # aggregate multiple results for bulk operations
    def self.aggregate_results(results)
      # if one of the commands fail it will be returned
      final_result = results.find {|r| !r[:success]}
      # if everything passes the last result will be returned that the service
      # is running else the failed step will be returned
      final_result ||= results[-1]
      # aggregate all the responses
      final_result[:response] = results.map { |r| r[:response] }
      # aggregate all the exit statuses
      final_result[:exitstatus] = results.map { |r| r[:exitstatus] }
      return final_result
    end
  end
end
