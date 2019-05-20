module BushSlicer
  class ClusterOperator < ClusterResource
    RESOURCE = "clusteroperators"
    # return the an array of versions for a particular clusteroperator
    def versions(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'versions').map { |v| v['version'] if v['name'] == 'operator' }.compact
    end
    # given a target_version return true if has matching version else false
    def version_exists?(version:, user: nil, cached: true, quiet: false)
      res = self.versions.select { |v| v == version }
      res.count != 0
    end

    # return Hash of conditions for easier access
    def conditions(user: nil, cached: true, quiet: false)
      conditions = raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'conditions')
      cond_hash = {}
      conditions.each do |con|
        cond_hash[con['type']] = con
      end
      cond_hash
    end
  end
end
