Given /^the #{QUOTED} #{QUOTED} CRD is recreated after scenario$/ do |name, crd|
  ensure_admin_tagged
  allowed_crds = ["kubeapiserver", "openshiftapiserver"]

  if allowed_crds.include? crd
    cb.cluster_resource_to_recreate = resource(name, crd)
    step 'hidden recreate cluster resource after scenario'
  else
    raise "#{crd} not supported by this step"
  end
end

Given /^the #{QUOTED} #{QUOTED} CR is restored after scenario$/ do |name, crd|
  ensure_admin_tagged
  ensure_destructive_tagged
  org_crd = {}
  @result = admin.cli_exec(:get, resource: crd, resource_name: name, o: 'yaml')
  if @result[:success]
    org_crd['spec'] = @result[:parsed]['spec']
    logger.info "#{crd} restore tear_down registered:\n#{org_crd}"
  else
    raise "Could not get #{crd}: #{name}"
  end
  patch_json = org_crd.to_json
  _admin = admin
  teardown_add {
    opts = {resource: crd, resource_name: name, p: patch_json, type: 'merge' }
    @result = _admin.cli_exec(:patch, **opts)
    raise "Cannot restore #{crd}: #{name}" unless @result[:success]
  }
end

Given /^I remove all CRDs with labels:$/ do | table |
  ensure_admin_tagged
  ensure_destructive_tagged
  labels = table.raw.flatten
  timeout = 60
  res = BushSlicer::CustomResourceDefinition.wait_for_labeled(*labels, user: user, seconds: timeout)
  if res[:success]
    crd_names = res[:parsed]['items'].map { |r| r['metadata']['name'] }
    crd_names.each do | crd |
      step %Q/I ensure "#{crd}" custom_resource_definition is deleted/
    end
  end
end

