require 'openshift/cluster_resource'

module BushSlicer
  # represents Metering CRD
  class KataConfig < ClusterResource
    RESOURCE = 'kataconfigs'

    def install_completed_node_count(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'installationStatus', 'completed', 'completedNodesList')&.count || 0
      #raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'installationStatus', 'completed', 'completedNodesCount')
    end

    def total_nodes_count(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'totalNodesCount')
    end

    def wait_till_installed_counter_match(user: nil, seconds: 600, count: nil)
      stats = {}
      result = {
        instruction: "wait till kataruntime is installed to all worker nodes",
        success: false,
      }
      result[:success] = wait_for(seconds, stats: stats) do
        counters = install_completed_node_count(user: user, quiet: true, cached: false)
        counters == count
        #counters.count == count unless counters.nil?
      end
      logger.info "After #{stats[:iterations]} iterations\n" \
        "and #{stats[:full_seconds]} seconds:\n" \
        "#{install_completed_node_count(user: user, quiet: true).inspect}"

      unless result[:success]
        logger.warn "#{shortclass}: timeout waiting for installed counters " \
          "to match; last state:\n\$ #{result[:command]}\n#{result[:response]}"
      end
      result
    end

  end
end
