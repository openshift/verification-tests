require 'openshift/cluster_resource'

module BushSlicer
  # represents Machine
  class Machine < ProjectResource
    RESOURCE = 'machines'

    # returns the node name the machine linked to
    def linked_node(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('status', 'nodeRef', 'name')
    end
  end
end
