## installer related steps such as upgrade

# required input: to_image in the calling step, which can be passed manually or set in the environment variable
# UPGRADE_TARGET_VERSION
Given /^I upgrade my cluster to:$/ do | table |
  transform binding, :table
  ensure_admin_tagged
  _admin = admin
  opts = opts_array_to_hash(table.raw)
  opts[:force] = true
  target_version = opts[:to_image]
  # patch spec.upstream
  upstream_url = opts[:upstream_url] if opts[:upstream_url]
  upstream_url ||= "https://openshift-release.svc.ci.openshift.org/graph"
  patch_json = {"spec": {"upstream":"#{upstream_url}"}}
  patch_opts = {resource: "clusterversion", resource_name: "version", p: patch_json.to_json, type: "merge"}
  @result = _admin.cli_exec(:patch, **patch_opts)
  raise "Patch failed with #{@result[:response]}" unless @result[:success]
  opts[:to_image] = cluster_version('version').initial_image_url + ":" + opts[:to_image]
  @result = _admin.cli_exec(:oadm_upgrade, opts)
  raise "Upgrade command failed #{@result[:response]}" unless @result[:success]
  upgrade_status = cluster_version('version').wait_for_upgrade_completion(version: target_version)
  raise "Upgrade to #{target_version} failed" unless upgrade_status
  # added extra check to make sure all clusteroperators do not have DEGRADED
  # status and all of the has the target version
  step %Q/all clusteroperators reached version "#{target_version}" successfully/
end

