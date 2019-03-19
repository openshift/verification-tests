Given /^the #{QUOTED} #{QUOTED} CRD is recreated after scenario$/ do |name, crd|
  ensure_admin_tagged
  allowed_crds = ["oauth", "kubeapiserver"]

  if allowed_crds.included? 'crd'
    cb.cluster_resource_to_recreate = crd(name)
    step 'hidden recreate cluster resource after scenario'
  else
    raise 'No such crd CRD in the cluster'
  end
end
