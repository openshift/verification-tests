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

# helper method to enabled qe-app-registry
# @args
# 1. catalogname (default to `qe-app-registry` if none is given)
# 2. index-version: if none is given, then just use the oc master version of the cluster
# 3. test_type: `stage` or nil.
Given /^I create #{QUOTED} catalogsource(?: with index version #{QUOTED})? for#{OPT_QUOTED} testing$/ do |catalog_name, index_version, test_type|
  ensure_admin_tagged
  ensure_destructive_tagged
  step %Q/I store master major version in the :master_version clipboard/ unless index_version
  index_version ||= cb.master_version
  # find out what the test_type is,
  test_type ||= ENV['OCP_TEST_TYPE']

  project("openshift-marketplace")
  if test_type=='stage' and index_version > "4.4"
    iib="registry-proxy.engineering.redhat.com/rh-osbs/iib-pub-pending:v#{index_version}"
  else
    if %w(4.1 4.2 4.3 4.4 4.5).include? index_version
      iib = "quay.io/openshift-qe-optional-operators/qe45-index:latest"
    else
      iib = "quay.io/openshift-qe-optional-operators/ocp4-index:latest"
    end
  end
  logger.info("Using IIB #{iib}...")
  cb.iib = iib
  cb.catalog_name = catalog_name
  step %Q/I switch to cluster admin pseudo user/
  if catalog_source(catalog_name).exists?
    # step %Q/I ensure "#{catalog_name}" opsrc is deleted/
    step %Q/I ensure "#{catalog_name}" catalogsource is deleted/
    step %Q/I ensure "#{catalog_name}" deployment is deleted/
  end
  # create policy
  step %Q|I obtain test data file "catalogsource/image_content_soruce_policy.yaml"|
  admin.cli_exec(:create, f: 'image_content_soruce_policy.yaml')
  step %Q(I run oc create as admin over ERB test file: catalogsource/catalog_source.yaml)
  step %Q(all pods in the project are ready)
end
