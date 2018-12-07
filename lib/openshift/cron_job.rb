require 'openshift/project_resource'

module VerificationTests
  # represents an OpenShift CronJob https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
  class CronJob < ProjectResource
    RESOURCE = "cronjobs"

    def schedule(user: nil, cached: true, quiet: false)
      spec = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec')
      spec.dig('schedule')
    end

  end
end
