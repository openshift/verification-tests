module BushSlicer
  class ClusterVersion < ClusterResource
    RESOURCE = "clusterversions"
    def channel(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'channel')
    end

    def cluster_id(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'clusterID')
    end

    def upstream(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'upstream')
    end

    def version(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'desired', 'version')
    end

    def history(user: nil, cached: false, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'history')
    end

    # return a list of history matching the state we want to filter on
    # query_hash is the parameter we want to filter on,
    def history_matching(key: nil, value:nil , user: nil, cached: true, quiet: false)
      self.history.select { |h| h[key] == value }
    end

    def image(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'desired', 'image')
    end

    # get the last entry of the spec.history which should be where the original
    def initial_image_url(user: nil, cached: true, quiet: false)
      self.history.last['image'].split('@sha256:')[0]
    end

    # @param version [String] upgrade version that we check for completion
    def upgrade_completed?(version:, user: nil, cached: true, quiet: false)
      res = self.history_matching(key: 'version', value: version)
      if res.count > 0
        logger.debug("MSG: #{res.first['message']}")
        res.first['state'] == 'Completed'
      else
        false
      end
    end

    def wait_for_upgrade_completion(version:, user: nil, quiet: false, timeout: 2*60*60)
      wait_for(timeout) {
        upgrade_completed?(version: version, user: user, cached: false, quiet: quiet)
      }
    end
    # extract the percentage done from the message field from spec.conditions
    # default to return nil if no upgarde is being done.
    def completed_percentage(user: nil, cached: true, quiet: false)
      progressing_cond = self.condition(type: 'Progressing')
      percent_done = nil
      if progressing_cond
        percent_regexp = /(\d+)%/
        found_percent = percent_regexp.match(progressing_cond['message'])
        percent_done = found_percent[1].to_i if found_percent
      end
      percent_done
    end

    def capabilities(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'capabilities')
    end

    def enabled_capabilities(user: nil, cached: true, quiet: false)
      capabilities.dig('enabledCapabilities')
    end

    def known_capabilities(user: nil, cached: true, quiet: false)
      capabilities.dig('knownCapabilities')
    end

    def capability_is_enabled?(capability:, user: nil,cached: true, quiet: false)
      cluster_enabled_caps = self.enabled_capabilities(user: user, cached: cached, quiet: quiet)
      cluster_enabled_caps.include? capability
    end

  end
end
