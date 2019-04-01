## installer related steps such as upgrade
#
Given /^I upgrade my cluster to:$/ do | table |
  ensure_admin_tagged
  _admin = admin
  upgrade_timeout = 2 * 60 * 60  # 2 hrs.
  opts = opts_array_to_hash(table.raw)
  opts[:force] = true
  target_version = opts[:to_image]
  opts[:to_image] = cluster_version('version').image_base_url + ":" + opts[:to_image]
  @result = _admin.cli_exec(:oadm_upgrade, opts)
  upgrade_status = cluster_version('version').wait_for_upgrade_completion(target_version: ENV['UPGRADE_TARGET_VERSION'])
  raise "Upgrade to #{ENV['UPGRADE_TARGET_VERSION']} failed" unless upgrade_status
end

