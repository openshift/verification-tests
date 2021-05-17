Given /^the #{QUOTED} scheduler priorityclasses is restored after scenario$/ do |name|
  _admin = admin
  teardown_add {
    opts = {object_type: 'priorityclasses', object_name_or_id: name}
    @result = _admin.cli_exec(:delete, **opts)
    raise "Cannot delete priorityclass: #{name}" unless @result[:success]
  }
end

Given /^the CR #{QUOTED} named #{QUOTED} is restored after scenario$/ do |crd, name|
  ensure_admin_tagged
  ensure_destructive_tagged
  org_scheduler = {}
  @result = admin.cli_exec(:get, resource: crd, resource_name: name, o: 'yaml')
  if @result[:success]
    org_scheduler['spec'] = @result[:parsed]['spec']
    logger.info "scheduler restore tear_down registered:\n#{org_scheduler}"
  else
    raise "Could not get scheduler: #{name}"
  end
  patch_json = org_scheduler.to_json
  _admin = admin
  teardown_add {
    # Added code to support removal of tlsSecurityProfile while restoring
    @result = admin.cli_exec(:get, resource: crd, resource_name: name, o: 'yaml')
    if @result[:success] and @result[:parsed]['spec']['tlsSecurityProfile']
      patch_json = [{"op": "remove","path": "/spec/tlsSecurityProfile"}].to_json
      opts = {resource: crd, resource_name: name, p: patch_json, type: 'json' }
    else
      opts = {resource: crd, resource_name: name, p: patch_json, type: 'merge' }
    end
    @result = _admin.cli_exec(:patch, **opts)
    raise "Cannot restore crd: #{name}" unless @result[:success]
    timeout = 300
    if crd == 'kubescheduler'
       crd = 'kube-scheduler'
    end
    wait_for(timeout) do
      @result = admin.cli_exec(:get, resource: "clusteroperators", resource_name: crd, o: "jsonpath={.status.conditions[?(.type == \"Progressing\")].status}")
      if @result[:response] == "True"
        break
      end
    end
    wait_for(timeout) do
      @result = admin.cli_exec(:get, resource: "clusteroperators", resource_name: crd, o: "jsonpath={.status.conditions[?(.type == \"Progressing\")].status}")
      if @result[:response] == "False"
        break
      end
    end
    wait_for(timeout) do
      @result = admin.cli_exec(:get, resource: "clusteroperators", resource_name: crd, o: "jsonpath={.status.conditions[?(.type == \"Degraded\")].status}")
      if @result[:response] == "False"
        break
      end
    end
    wait_for(timeout) do
      @result = admin.cli_exec(:get, resource: "clusteroperators", resource_name: crd, o: "jsonpath={.status.conditions[?(.type == \"Available\")].status}")
      if @result[:response] == "True"
        break
      end
    end
  }
end
