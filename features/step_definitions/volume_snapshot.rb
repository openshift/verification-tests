Given /^I check volume snapshot is deployed$/ do
  ensure_admin_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "default" project/
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=snapshot-controller |
    })
  step %Q/I switch to the default user/
end
