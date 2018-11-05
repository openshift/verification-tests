Given /^the azure file secret name and key are stored to the clipboard$/ do
  ensure_admin_tagged
  cb.dynamic_pvc_name = rand_str(8, :dns)
  cb.storage_class_name = rand_str(8, :dns)
  azsac = conf[:services, :azure, :pv_storage_account]
  step %Q{admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/azure-file/azfsc-ACONLY.yaml" where:}, table(%{
    | ["metadata"]["name"]             | <%= cb.storage_class_name %> |
    | ["parameters"]["storageAccount"] | #{azsac}                     |
    })
  step %Q/the step should succeed/
  step %Q{I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/azure/azpvc-sc.yaml" replacing paths:}, table(%{
    | ["metadata"]["name"]                                                   | <%= cb.dynamic_pvc_name %>   |
    | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | <%= cb.storage_class_name %> |
    })
  step %Q/the step should succeed/
  step %Q/the "<%= cb.dynamic_pvc_name %>" PVC becomes :bound within 120 seconds/
  cb['asan'] = secret("azure-storage-account-#{azsac}-secret").raw_value_of("azurestorageaccountname")
  cb['asak'] = secret("azure-storage-account-#{azsac}-secret").raw_value_of("azurestorageaccountkey")
end
