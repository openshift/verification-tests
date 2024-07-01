
Given(/^the "([^"]*)" capability is enabled$/) do |capability|
  logger.info("Checking if capability '#{capability}' is enabled...\n")
  unless cluster_version('version').capability_is_enabled?(capability: capability)
    logger.warn("ClusterVersion does not have '#{capability}' enabled.")
    skip_this_scenario("#{capability} capability is not enabled. Skipping this scenario.")
  else
    logger.info("ClusterVersion does have '#{capability}' enabled.")
  end
end
