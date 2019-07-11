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
    # @return an array of relatedObjects
    #   relatedObjects:
    #   - group: ""
    #     name: openshift-cluster-storage-operator
    #     resource: namespaces
    #   - group: config.openshift.io
    #     name: cluster
    #     resource: infrastructures
    #   - group: storage.k8s.io
    #     name: gp2
    #     resource: storageclasses
    def related_objects(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'relatedObjects')
    end

    # @param filter_by [String] the hash key to filter by
    # @param value [String] the value that we wish to match for selection
    def related_object(filter_by:, value:, user: nil, cached: true, quiet: false)
      ro = related_objects(user: user, cached: cached, quiet: quiet).select { |r|  r[filter_by] == value }
      ro.first
    end

  end
end
