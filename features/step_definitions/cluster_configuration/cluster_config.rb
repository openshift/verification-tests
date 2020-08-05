# https://docs.openshift.com/container-platform/4.1/machine_management/applying-autoscaling.html
# two steps, 1. create clusterautoscaler, follow by machineautoscaler
# example of machine auto-scaler https://github.com/openshift-qe/output_references/blob/master/autoscale/machine-autoscaler.yaml
Given /^I enable autoscaling for my cluster$/ do
  ensure_admin_tagged
  ensure_destructive_tagged

  base_template_hash = {
    "apiVersion" => "autoscaling.openshift.io/v1beta1",
    "kind" => "MachineAutoscaler",
    "metadata" => {
      "namespace" => "openshift-machine-api"
    },
    "spec" => {
      "minReplicas" => 4,
      "maxReplicas" => 10,
      "scaleTargetRef" => {
        "apiVersion" => "machine.openshift.io/v1beta1",
        "kind" => "MachineSet",
      }
    }
  }
  # first create cluster autoscaler
  cluster_autoscaler_yaml = "#{BushSlicer::HOME}/testdata/metering/cluster-autoscaler.yaml"
  admin.cli_exec(:create, f: cluster_autoscaler_yaml)
  step %Q/I store all machinesets in the "openshift-machine-api" project to the :machinesets clipboard/
  cb.machinesets.each do | machineset |
    # we need to add the `name` elements
    base_template_hash['spec']['scaleTargetRef']['name'] = machineset.name
    base_template_hash['metadata']['name'] = machineset.name
    @result = admin.cli_exec(:create, f: "-", _stdin: base_template_hash.to_yaml)
    raise "Failed to create MachineAutoscaler" unless @result[:success]
  end
end

