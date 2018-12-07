module VerificationTests
  class Container
    include Common::Helper

    def initialize(name:, pod:)
      @name = name
      if pod.kind_of? Pod
        @pod = pod
      else
        raise "#{pod} needs to be of type Pod"
      end
    end

    # return @Hash information of container status matching the @name variable
    def status(user: nil, cached: true, quiet: false)
      container_statuses = @pod.status_raw(user: user, cached: cached, quiet: quiet)['containerStatuses']
      stat = {}
      container_statuses.each do | cs |
        stat = cs if cs['name'] == @name
      end
      return stat
    end

    # return @Hash information of container spec matching the @name variable
    def spec(user: nil, cached: true, quiet: false)
      @pod.container_specs(user: user, cached: cached, quiet: quiet).find { |cs|
        cs.name == name
      }
    end

    ## status related information for the container @name
    def id(user: nil, cached: true, quiet: false)
      res = status(user: user, cached: cached, quiet: quiet)
      # handle docker:// and cri-o://, basically we are assuming all will have xxx://<container_id>
      return res['containerID'].split("://").last
    end

    def image(user: nil, cached: true, quiet: false)
      res = status(user: user, cached: cached, quiet: quiet)
      return res['image'].split('@sha256:')[0]
    end

    def image_id(user: nil, cached: true, quiet: false)
      res = status(user: user, cached: cached, quiet: quiet)
      return res['imageID'].split('sha256:').last
    end

    def name(user: nil, cached: true, quiet: false)
      res = status(user: user, cached: cached, quiet: quiet)
      return res['name']
    end

    # returns @Boolean representation of the container state
    def ready?(user: nil, cached: true, quiet: false)
      res = status(user: user, cached: cached, quiet: quiet)
      return res['ready']  # return @status['ready']
    end

    # returns @Boolean representation of the container termination state
    def completed?(user: nil, cached: false, quiet: false)
      container_state = status(user: user, cached: cached, quiet: quiet)['state']
      current_state =  container_state.keys.first
      terminated_reason = container_state['terminated']['reason'] if current_state == 'terminated'
      expected_status = 'Completed'
      res = {
        instruction: "get containter state",
        response: "matched state: '#{terminated_reason}' while expecting '#{expected_status}'",
        matched_state: terminated_reason,
        exitstatus: 0
      }
      res[:success] = terminated_reason == expected_status
      return res
    end

    def last_completed(user: nil, cached: false, quiet: false)
      container_state = status(user: user, cached: cached, quiet: quiet)['lastState']
      current_state =  container_state.keys.first
      terminated_reason = container_state['terminated']['reason'] if current_state == 'terminated'
      expected_status = 'Completed'
      res = {
        instruction: "get containter state",
        response: "matched state: '#{terminated_reason}' while expecting '#{expected_status}'",
        matched_state: terminated_reason,
        exitstatus: 0
      }
      res[:success] = terminated_reason == expected_status
      return res
    end

    def wait_till_completed(seconds, quiet: false, cached: false)
      res = nil
      iterations = 0
      start_time = monotonic_seconds

      success = wait_for(seconds) {
        res = completed?(quiet: true)
        logger.info res[:instruction] if iterations == 0
        iterations = iterations + 1

        res[:success]
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        "seconds:\n#{res[:response]}"

      res[:success] = success
      return res
    end

    # containterStatuses related methods, need to keyed off by container name
    def restart_count(user: nil, cached: false, quiet: false)
      res = status(user: user, cached: cached, quiet: quiet)
      return res['restartCount']
    end

    def state(user: nil, cached: false, quiet: false)
      res = status(user: user, cached: cached, quiet: quiet)
      return res['state']
    end
  end
end
