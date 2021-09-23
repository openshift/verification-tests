require 'openshift/project_resource'

module BushSlicer
  # represents an OpenShift CronJob https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
  class CronJob < ProjectResource
    RESOURCE = "cronjobs"

    def schedule(user: nil, cached: true, quiet: true)
      spec = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec')
      spec.dig('schedule')
    end

    def template(user: nil, cached: true, quiet: false)
      job_template = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'jobTemplate')
      job_template.dig('spec', 'template')
    end

    def containers_spec(user: nil, cached: true, quiet: false)
      specs = []
      containers_spec = template(user: user, cached: cached, quiet: quiet)['spec']['containers']
      containers_spec.each do | container_spec |
        specs.push ContainerSpec.new container_spec
      end
      return specs
    end

    # return the spec for a specific container identified by the param name
    def container_spec(user: nil, name:, cached: true, quiet: false)
      specs = containers_spec(user: user, cached: cached, quiet: quiet)
      target_spec = {}
      specs.each do | spec |
        target_spec = spec if spec.name == name
      end
      raise "No container spec found matching '#{name}'!" if target_spec.is_a? Hash
      return target_spec
    end

    def node_selector(user: nil, cached: true, quiet: false)
      template(user: user, cached: cached, quiet: quiet).dig('spec', 'nodeSelector')
    end

    def tolerations(user: nil, cached: true, quiet: false)
      template(user: user, cached: cached, quiet: quiet).dig('spec', 'tolerations')
    end

  end
end
