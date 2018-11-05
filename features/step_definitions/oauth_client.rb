Given /^the #{QUOTED} oauth client is recreated after scenario?$/ do |name|
  cb.cluster_resource_to_recreate = o_auth_client(name)
  step 'hidden recreate cluster resource after scenario'
end
