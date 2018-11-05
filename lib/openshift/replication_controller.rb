require 'openshift/project_resource'
require 'openshift/pod_replicator'

require 'openshift/flakes/container_spec'

module BushSlicer
  # represents an OpenShift ReplicationController (rc for short) used for scaling pods
  class ReplicationController < PodReplicator
    RESOURCE = "replicationcontrollers"
    REPLICA_COUNTERS = {
      desired: %w[spec replicas].freeze,
      current: %w[status replicas].freeze,
      ready:   %w[status readyReplicas].freeze,
    }.freeze

    # @param from_status [Symbol] the status we currently see
    # @param to_status [Array, Symbol] the status(es) we check whether current
    #   status can change to
    # @return [Boolean] true if it is possible to transition between the
    #   specified statuses (same -> same should return true)
    def status_reachable?(from_status, to_status)
      [to_status].flatten.include?(from_status) ||
        ![:failed, :succeeded].include?(from_status)
    end

    # @param status [Symbol, Array<Symbol>] the expected statuses as a symbol
    # @return [Boolean] if pod status is what's expected
    # def status?(user:, status:, quiet: false, cached: false)
    #   statuses = {
    #     waiting: "Waiting",
    #     running: "Running",
    #     succeeded: "Succeeded",
    #     failed: "Failed",
    #     complete: "Complete",
    #   }
    #   res = describe(user, quiet: quiet)
    #   if res[:success]
    #     pods_status = res[:parsed][:pods_status]
    #     res[:success] = (pods_status[status].to_i != 0)
    #   end
    #   return res
    # end

    def selector(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "selector")
    end

    # we define this in method_missing so alias can't fly
    # alias expected_replicas desired_replicas
    def expected_replicas(*args, &block)
      desired_replicas(*args, &block)
    end

    ### if we look at the output below, a rc is ready only when the READY column
    # matches the DESIRED column
    # [root@openshift-141 ~]# oc get rc  -n openshift-infra
    # NAME                   DESIRED   CURRENT   READY     AGE
    # hawkular-cassandra-1   1         1         1         4m
    # hawkular-metrics       1         1         0         4m
    # heapster               1         1         0         4m

    # pry(main)> heapster['status']
    # => {"fullyLabeledReplicas"=>1, "observedGeneration"=>1, "readyReplicas"=>1, "replicas"=>1}
    # NOTE, the readyReplicas key is not there if the READY column is 0
    # return: Integer (number of replicas that are in the ready state)
    def ready_replicas(user: nil, cached: true, quiet: false)
      if env.version_ge("3.4", user: user)
        return super(user: user, cached: cached, quiet: quiet).to_i
      else
        pods = pods(user: user, cached: cached, quiet: quiet).select { |p|
          p.ready?(user: user, cached: true)
        }
        return pods.size
      end
    end

    # lists this replica set's managed pods
    def pods(user: nil, cached: true, quiet: false)
      if cached && props[:pods]
        return props[:pods]
      else
        user ||= default_user(user)
        # I believe selector never changes thus cached selector should be fine
        labels = selector(user: user)
        props[:pods] = Pod.get_matching(
          user: user,
          project: project,
          get_opts: {
            l: selector_to_label_arr(*labels),
            _quiet: quiet
          }
        )
        return props[:pods]
      end
    end

    def deployment_phase(user: nil, quiet: false, cached: true)
      annotation("openshift.io/deployment.phase",
                user: user,
                cached: cached,
                quiet: quiet)
    end

    # @return [BushSlicer::ResultHash] with :success when ready and desired
    #   replicas match and are more than zero
    # @note the complicated logic t oconstruct a result hash is to keep
    #   backward compatibility
    def ready?(user: nil, quiet: false, cached: false)
      if cached && self.cached?
        resource = raw_resource(user: user, cached: true, quiet: quiet)
        res = {
          success: true,
          instruction: "get rc #{name} cached ready status",
          response: resource.to_yaml,
          parsed: resource
        }
      else
        res = get(user: user, quiet: quiet)
        return res unless res[:success]
      end

      # TODO: this doesn't make much sense to me atm
      res[:success] = expected_replicas.to_i > 0 &&
        current_replicas == ready_replicas(user: user) &&
        (deployment_phase == 'Complete' || deployment_phase.nil?)

      return res
    end

    # @return [BushSlicer::ResultHash]
    def replica_count_match?(user:, state:, replica_count:, quiet: false)
      res = describe(user, quiet: quiet)
      if res[:success]
        res[:success] = res[:parsed][:pods_status][state].to_i == replica_count
      end
      return res
    end

    def suplemental_groups(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: true, quiet: quiet)
      sg = rr.dig('spec','template','spec','securityContext','supplementalGroups')
    end
  end
end
