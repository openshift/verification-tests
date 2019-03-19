Given /^the #{QUOTED} #{QUOTED} CRD is recreated after scenario$/ do |name, crd|
  ensure_admin_tagged
  allowed_crds = ["kubeapiserver"]

  if allowed_crds.include? crd
    cb.cluster_resource_to_recreate = self.send(crd, name)
    step 'hidden recreate cluster resource after scenario'
  else
    raise "#{crd} not supported by this step"
  end
end
