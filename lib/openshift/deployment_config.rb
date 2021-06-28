# frozen_string_literal: true

require 'openshift/pod_replicator'
require 'openshift/replication_controller'

require 'openshift/flakes/container_spec'
require 'openshift/flakes/deployment_config_trigger'

module BushSlicer

  # represents an OpenShift DeploymentConfig (dc for short) used for scaling pods
  class DeploymentConfig < PodReplicator
    RESOURCE = 'deploymentconfigs'
    STATUSES = %i[waiting running succeeded failed complete].freeze
    REPLICA_COUNTERS = {
      desired: %w[spec replicas].freeze,
      current: %w[status replicas].freeze,
      all: %w[status replicas].freeze,
      available: %w[status availableReplicas].freeze,
      updated: %w[status updatedReplicas].freeze,   # CURRENT column
      unavailable: %w[status unavailableReplicas].freeze,
      ready: %w[status readyReplicas].freeze
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
    # @note TODO: can we just remove method and use [Resource#status?]
    def status?(user:, status:, quiet: false, cached: false)
      statuses = {
        waiting: "Waiting",
        running: "Running",
        succeeded: "Succeeded",
        failed: "Failed",
        complete: "Complete",
      }
      res = describe(user, quiet: quiet)
      if res[:success]
        status = [ status ].flatten
        overall_status = res[:parsed][:overall_status]
        res[:success] = status.any? {|s| statuses[s] == overall_status }
          res[:parsed][:overall_status] == statuses[status]
      end
      return res
    end

    # @return [BushSlicer::ResultHash] with :success depending the rc readiness for the dc that it belongs to
    def ready?(user: nil, cached: false, quiet: false)
      rc(user: user, cached: cached, quiet: quiet).ready?(user: user, cached: cached, quiet: quiet)
    end

    def replicas(user: nil, cached: false, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'replicas').to_i
    end

    def available_replicas(user: nil, cached: false, quiet: false)
      if env.version_ge("3.3", user: user)
        return super(user: user, cached: cached, quiet: quiet)
      else
        res = describe(user, quiet: quiet)
        raise "cannot describe dc #{name}" unless res[:success]
        return res[:parsed][:replicas_status][:current].to_i
      end
    end

    def latest_version(user: nil, cached: false, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("status", "latestVersion")
    end

    # @return [BushSlicer::ReplicationController]
    def replication_controller(user: nil, cached: true, quiet: true)
      version = latest_version(user: user, cached: cached, quiet: quiet)

      if props[:rc]&.name&.end_with?("-#{version}")
        return props[:rc]
      else
        rc_name = "#{name}-#{version}"
        props[:rc] = ReplicationController.new(name: rc_name, project: project)
        props[:rc].default_user = default_user(user)
        return props[:rc]
      end
    end
    alias rc replication_controller

    def replication_controller=(rc)
      props[:rc] = rc
    end
    alias rc= replication_controller=

    # availablity check only exists in 3.3, and oc describe doesn't have that
    # information prior, so we can't use the same logic to check for that info
    # @note only works with v3.3+

    def strategy(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "strategy")
    end

    def selector(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "selector")
    end

    def containers(user: nil, cached: false, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "template", "spec", "containers")
    end

    # @return [Array<DeploymentConfigTrigger>]
    def triggers(user: nil, cached: true, quiet: false)
      if cached && props[:triggers]
        return props[:triggers]
      else
        triggers = raw_resource(user: user, cached: cached, quiet: quiet).
          dig("spec", "triggers") || []
        props[:triggers] = DeploymentConfigTrigger.from_list(triggers, self)
        return props[:triggers]
      end
    end

    # return trigger params matched by type or nil
    def trigger_by_type(user: nil, type:, cached: true, quiet: false)
      triggers = self.triggers(user: user, cached: cached, quiet: quiet)
      triggers = triggers.select {|t| t.type == type}
      if triggers.size == 1
        return triggers[0]
      elsif triggers.size == 0
        raise "no #{type} triggers found for DC #{name}"
      else
        raise "confusing, found #{triggers.size} #{type} triggers for DC " \
          "#{name}, use some better method to select"
      end
    end

    def trigger_is_tags(user: nil, cached: true, quiet: false)
      triggers(user: user, cached: cached, quiet: quiet).select { |t|
        t.type == "ImageChange"
      }.map { |t| t.from }
    end

    # This one basically finds build configs that update any of the is tags
    #   that trigger us. I'm not sure if there is any other way for a build
    #   config to trigger a deployment config.
    def trigger_build_configs(user: nil, cached: true, quiet: false,
                              project: nil)
      unless cached && props[:trigger_build_configs]
        bcs = BuildConfig.list(
          user: default_user(user),
          project: project || self.project
        )
        istags = trigger_is_tags(user: user, cached: cached, quiet: quiet)
        props[:trigger_build_configs] = bcs.select { |bc|
          istags.include? bc.output_to
        }
      end
      return props[:trigger_build_configs]
    end

    def revision_history_limit(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "revisionHistoryLimit")
    end

    # @return undefined
    # @raise on error
    def rollout_latest(user: nil, quiet: false)
      res = default_user(user).cli_exec(:rollout_latest,
                                              resource: "dc/#{name}",
                                              _quiet: quiet,
                                              n: project.name
                                             )
      unless res[:success]
        raise "could not redeploy dc #{name}" +
          (quiet ? ":\n#{res[:response]}" : ", see log")
      end
    end
  end
end
