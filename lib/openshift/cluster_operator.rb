module BushSlicer
  class ClusterOperator < ClusterResource
    RESOURCE = "clusteroperators"
    # return the an array of versions for a particular clusteroperator
    def versions(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'versions').map { |v| v['version'] }
    end

    def conditions(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'conditions')
    end

    # returns a hash simliar to
    # {"lastTransitionTime"=>2019-03-23 07:33:34 UTC, "status"=>"False", "type"=>"Progressing"}
    def condition(type: type, user: nil, cached: true, quiet: false)
      res = self.conditions.select { |c| c['type'] == type }
      res.first
    end
  end
end
