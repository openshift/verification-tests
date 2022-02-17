Given(/^([0-9]+?) seconds have passed when the cluster is Single Node Openshift$/) do |num|
  ensure_admin_tagged
  @result = env.nodes.length
  if @result == 1
    logger.info "Running step for single node cluster"
    sleep(num.to_i)
  end
end
