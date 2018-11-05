module BushSlicer
  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.9/#endpoints-v1-core
  class Endpoints < ProjectResource
    RESOURCE = "endpoints"

    # @return an array of EndpointSubsets
    def subsets(user: nil, cached: true, quiet: false)
      subsets = []
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      obj['subsets'].each do | s |
        es = EndpointSubset.new s
        subsets << es
      end
      return subsets
    end

  end
end
