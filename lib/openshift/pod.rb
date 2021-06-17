require 'openshift/project_resource'

require 'openshift/flakes/container'
require 'openshift/flakes/container_spec'
require 'openshift/flakes/pod_volume_spec'

module BushSlicer
  # represents an OpenShift pod
  class Pod < ProjectResource
    RESOURCE = "pods"
    # https://github.com/kubernetes/kubernetes/blob/master/pkg/api/types.go
    # added :completed which seems to be an Openshift term
    STATUSES = [:pending, :running, :succeeded, :failed, :unknown]
    # statuses that indicate pod running or completed successfully
    SUCCESS_STATUSES = [:running, :succeeded, :missing]
    TERMINAL_STATUSES = [:failed, :succeeded, :missing]

    # cache some usualy immutable properties for later fast use; do not cache
    #   things that ca nchange at any time like status and spec
    def update_from_api_object(pod_hash)
      super

      m = pod_hash["metadata"]
      props[:resourceVersion] = m["resourceVersion"]
      props[:generateName] = m["generateName"]
      props[:labels] = m["labels"]
      props[:created] = m["creationTimestamp"] # already [Time]
      props[:deleted] = m["deletionTimestamp"] # during grace period
      props[:grace_period] = m["deletionGracePeriodSeconds"] # might be nil
      props[:annotations] = m["annotations"]
      if m.has_key?("annotations")
        props[:deployment_config_version] = m["annotations"]["openshift.io/deployment-config.latest-version"]
        props[:deployment_config_name] = m["annotations"]["openshift.io/deployment-config.name"]
        props[:deployment_name] = m["annotations"]["openshift.io/deployment.name"]

        # for builder pods
        props[:build_name] = m["annotations"]["openshift.io/build.name"]
      end

      # for deployment pods
      # ???

      spec = pod_hash["spec"] # this is runtime, lets not cache
      props[:node_hostname] = spec["host"]
      props[:node_name] = spec["nodeName"]
      props[:securityContext] = spec["securityContext"]
      props[:service_account] = spec["serviceAccount"]
      props[:service_account_name] = spec["serviceAccountName"]
      props[:termination_grace_period_seconds] = spec['terminationGracePeriodSeconds']
      props[:volumes] = spec["volumes"]
      s = pod_hash["status"]
      props[:ip] = s["podIP"]
      props[:ips] = s["podIPs"]
      # status should be retrieved on demand but we cache it for the brave
      props[:status] = s

      return self # mainly to help ::from_api_object
    end

    # @return [BushSlicer::ResultHash] with :success depending on pod
    #   condition type=Ready and status=True; only `Running` pods with all
    #   containers probes succeeding appear to have this
    def ready?(user: nil, quiet: false, cached: false)
      if cached && props[:raw]
        res = { instruction: "get cached pod #{name} readiness",
                response: props[:raw].to_yaml,
                success: true,
                exitstatus: 0,
                parsed: props[:raw]
        }
      else
        res = get(user: user, quiet: quiet)
      end
      if res[:success]
        res[:success] =
          res[:parsed]["status"] &&
          res[:parsed]["status"]["conditions"] &&
          res[:parsed]["status"]["conditions"].any? { |c|
            c["type"] == "Ready" && c["status"] == "True"
          }
      end

      return res
    end

    def wait_till_terminating(user, seconds)

      stats = {}
      res = {
        instruction: "wait till pod #{name} reach terminating state",
        exitstatus: -1,
        success: false
      }

      res[:success] = !!wait_for(seconds, stats: stats) {
        t = terminating?(user: user, quiet: true)

        break if status?(user: user, status: TERMINAL_STATUSES,
                                 cached: true, quiet: true)[:success]

        t
      }

      res[:response] = "After #{stats[:iterations]} iterations and " <<
        "#{stats[:full_seconds]} seconds: " <<
        "#{res[:success] || phase(user: user, cached: true, quiet: true)}"
      logger.info res[:response]

      return res
    end

    # @note call without parameters only when props are loaded
    def ip(user: nil, cached: true, quiet: false)
      return get_cached_prop(prop: :ip, user: user, cached: cached, quiet: quiet)
    end

    def ip_v6(user: nil, cached: true, quiet: false)
      ips = get_cached_prop(prop: :ips, user: user, cached: cached, quiet: quiet)
      ipv6 = ips.find { |ip| ip["ip"].include? ":" }
      return ipv6["ip"]
    end

    # return pod ipv6 address as URL for dualstack cluster
    def ip_v6_url(user: nil, cached: true, quiet: false)
      return "[#{ip_v6(user: user, cached: cached, quiet: quiet)}]"
    end

    def ip_v4(user: nil, cached: true, quiet: false)
      ips = get_cached_prop(prop: :ips, user: user, cached: cached, quiet: quiet)
      ipv4 = ips.find { |ip| ip["ip"].include? "." }
      return ipv4["ip"]
    end

    # @return [String] string IP if IPv4 or [IP] if IPv6
    def ip_url(user: nil, cached: true, quiet: false)
      raw_ip = ip(user: user, cached: cached, quiet: quiet)
      raw_ip.include?(":") ? "[#{raw_ip}]" : raw_ip
    end

    # @note call without parameters only when props are loaded
    def nominated_node_name(user:nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("status", "nominatedNodeName")
    end

    # @note call without parameters only when props are loaded
    def terminating?(user: nil, cached: false, quiet: false)
      status?(user: user, status: :running,
              quiet: quiet, cached: cached)[:success] &&
        get_cached_prop(prop: :deleted, user: user, cached: true, quiet: true)
    end


    # @note call without parameters only when props are loaded
    # @return [Integer] fs_group UID
    def fs_group(user:, cached: true, quiet: false)
      spec = get_cached_prop(prop: :securityContext, user: user, cached: cached, quiet: quiet)
      return spec["fsGroup"]
    end

    # @return [Integer] uuid_range base
    def sc_run_as_user(user:, cached: true, quiet: false)
      spec = get_cached_prop(prop: :securityContext, user: user, cached: cached, quiet: quiet)
      return spec["runAsUser"]
    end

    # @return [Boolean] runAsNonRoot value
    def sc_run_as_nonroot(user:, cached: true, quiet: false)
      spec = get_cached_prop(prop: :securityContext, user: user, cached: cached, quiet: quiet)
      return spec["runAsNonRoot"]
    end

    def sc_selinux_options(user:, cached: true, quiet: false)
      spec = get_cached_prop(prop: :securityContext, user: user, cached: cached, quiet: quiet)
      return spec["seLinuxOptions"]
    end

    def supplemental_groups(user:, cached: true, quiet: false)
      spec = get_cached_prop(prop: :securityContext, user: user, cached: cached, quiet: quiet)
      return spec["supplementalGroups"]
    end

    # @return [Array<Container>] container objects belonging to a pod
    def containers(user: nil, cached: true, quiet: false)
      unless cached && props[:containers]
        props[:containers] = container_specs(user: user,
                                             cached: cached,
                                             quiet: quiet).map { |spec|
          BushSlicer::Container.new(name: spec.name, pod: self)
        }
      end
      return props[:containers]
    end

    # @return [Array<ContainerSpec>]
    def container_specs(user: nil, cached: true, quiet: false)
      unless cached && props[:container_specs]
        specs = raw_resource(user: user, cached: cached, quiet: quiet).
          dig("spec", "containers")
        props[:container_specs] = specs.map { |spec|
          ContainerSpec.new spec
        }
      end
      return props[:container_specs]
    end

    # return the Container object matched by the lookup parameter
    def container(user: nil, name:, cached: true, quiet: false)
      c = containers(user:user, cached: cached, quiet: quiet).find { |c|
        c.name == name
      } or raise "No container with name #{name} found."
    end

    # @note call without parameters only when props are loaded
    def node_hostname(user: nil, cached: true, quiet: false)
      return get_cached_prop(prop: :node_hostname, user: user, cached: cached, quiet: quiet)
    end

    # @note call without parameters only when props are loaded
    def node_name(user: nil, cached: true, quiet: false)
      return get_cached_prop(prop: :node_name, user: user, cached: cached, quiet: quiet)
    end

    # @note call without parameters only when props are loaded
    def resourceVersion(user: nil, cached: true, quiet: false)
      return get_cached_prop(prop: :resourceVersion, user: user, cached: cached, quiet: quiet)
    end

    def nodeselector(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "nodeSelector")
    end

    def runtime_class_name(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "runtimeClassName")
    end

    # @note call without parameters only when props are loaded
    def node_ip(user: nil, cached: true, quiet: false)
      return get_cached_prop(prop: :status, user: user, cached: cached, quiet: quiet)["hostIP"]
    end

    # @note call without parameters only when props are loaded
    def service_account(user: nil, cached: true, quiet: false)
      return get_cached_prop(prop: :service_account, user: user, cached: cached, quiet: quiet)
    end

    # @note call without parameters only when props are loaded
    def service_account_name(user: nil, cached: true, quiet: false)
      return get_cached_prop(prop: :service_account_name, user: user, cached: cached, quiet: quiet)
    end

    def termination_grace_period_seconds(user: nil, cached: true, quiet: false)
      return get_cached_prop(prop: :termination_grace_period_seconds, user: user, cached: cached, quiet: quiet)
    end

    private def volumes_raw(user: nil, cached: true, quiet: false)
      return get_cached_prop(prop: :volumes, user: user, cached: cached, quiet: quiet)
    end

    # @return [Array<PodVolumeSpec>]
    def volumes(user: nil, cached: true, quiet: false)
      unless cached && props[:volume_specs]
        raw = volumes_raw(user: user, cached: cached, quiet: quiet) || []
        props[:volume_specs] = raw.map {|vs| PodVolumeSpec.from_spec(vs, self) }
      end
      return props[:volume_specs]
    end

    # @return [Array<PersistentVolumeClaim>]
    def volume_claims(user: nil, cached: true, quiet: false)
      volumes(user: user, cached: cached, quiet: quiet).select { |v|
        PVCPodVolumeSpec === v
      }.map(&:claim)
    end

    def env_var(name, container: nil, user: nil, cached: true, quiet: false)
      if containers(user: user, cached: cached, quiet: quiet).length == 1 &&
          !container
        env_var = containers.first.spec.env.find { |e| e["name"] == name }
      elsif container
        env_var = container(cached: true, name: container).spec.env.find { |e|
          e["name"] == name
        }
      else
        raise "please specify container to get variable of"
      end
      return env_var && env_var["value"]
    end
    # this useful if you wait for a pod to die
    def wait_till_not_ready(user, seconds)
      res = nil
      iterations = 0
      start_time = monotonic_seconds

      success = wait_for(seconds) {
        res = ready?(user: user, quiet: true)

        logger.info res[:command] if iterations == 0
        iterations = iterations + 1

        ! res[:success]
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        "seconds:\n#{res[:response]}"

      res[:success] = success
      return res
    end

    # @param from_status [Symbol] the status we currently see
    # @param to_status [Array, Symbol] the status(es) we check whether current
    #   status can change to
    # @return [Boolean] true if it is possible to transition between the
    #   specified statuses (same -> should be true)
    def status_reachable?(from_status, to_status)
      [to_status].flatten.include?(from_status) ||
        ![:failed, :succeeded, :unknown].include?(from_status)
    end

    def ready_state_reachable?(user: nil, cached: true, quiet: false)
      from_status = phase(user: user, cached: cached, quiet: quiet)
      to_status = :running # according to #ready? only running pods apply
      return status_reachable?(from_status, to_status)
    end

    # executes command on pod
    def exec(command, *args, as:, container:nil, stdin: nil)
      #opts = []
      #opts << [:pod, name]
      #opts << [:cmd_opts_end, true]
      #opts << [:exec_command, command]
      #args.each {|a| opts << [:exec_command_arg, a]}
      #
      #env.cli_executor.exec(as, :exec, opts)

      default_user(as).cli_exec(:exec, pod: name, n: project.name,
               container: container,
               i: !!stdin,
               oc_opts_end: true,
               exec_command: command,
               exec_command_arg: args,
               _stdin: stdin)
    end

    def tolerations(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'tolerations')
    end

  end
end
