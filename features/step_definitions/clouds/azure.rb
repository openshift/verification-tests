Given /^azure file dynamic provisioning is enabled in the#{OPT_QUOTED} project$/ do |project_name|
  transform binding, :project_name
  project(project_name)
  project(generate: false)
  step %Q{I run oc create over "#{BushSlicer::HOME}/testdata/storage/azure-file/azf-role.yaml" replacing paths:}, table(%{
    | ["metadata"]["namespace"] | #{project.name} |
    })
  step %Q/the step should succeed/
  step %Q{I run oc create over "#{BushSlicer::HOME}/testdata/storage/azure-file/azf-rolebind.yaml" replacing paths:}, table(%{
    | ["metadata"]["namespace"] | #{project.name} |
    })
  step %Q/the step should succeed/
  step %Q{I run the :policy_add_role_to_user client command with:}, table(%{
    | role      | admin                                                      |
    | user_name | system:serviceaccount:kube-system:persistent-volume-binder |
    | n         | #{project.name}                                            |
    })
  step %Q/the step should succeed/
end
