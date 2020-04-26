Given /^the azure file secret name and key are stored to the clipboard$/ do
  ensure_admin_tagged
  random_name = rand_str(8, :dns)
  step %Q{admin creates a StorageClass from "#{ENV['BUSHSLICER_HOME']}/testdata/storage/azure-file/azfsc-NOPAR.yaml" where:}, table(%{
    | ["metadata"]["name"]  | sc-#{random_name} |
    | ["volumeBindingMode"] | Immediate         |
    })
  step %Q/the step should succeed/
  step %Q/I ensure "pvc-#{random_name}" pvc is deleted after scenario/
  step %Q{I create a dynamic pvc from "#{ENV['BUSHSLICER_HOME']}/testdata/storage/misc/pvc.json" replacing paths:}, table(%{
    | ["metadata"]["name"]         | pvc-#{random_name} |
    | ["spec"]["storageClassName"] | sc-#{random_name}  |
    })
  step %Q/the step should succeed/
  step %Q/the "pvc-#{random_name}" PVC becomes :bound/

  step %Q{I run the :get admin command with:}, table(%{
    | resource      | pv                             |
    | resource_name | <%= pvc.volume_name %>         |
    | template      | {{.spec.azureFile.secretName}} |
  })
  step %Q/the step should succeed/
  step %Q/evaluation of `@result[:response]` is stored in the :secretName clipboard/
  step %Q{I run the :get admin command with:}, table(%{
    | resource      | pv                            |
    | resource_name | <%= pvc.volume_name %>        |
    | template      | {{.spec.azureFile.shareName}} |
  })
  step %Q/the step should succeed/
  step %Q/evaluation of `@result[:response]` is stored in the :shareName clipboard/
end
