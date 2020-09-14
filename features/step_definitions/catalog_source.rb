Given(/^admin creates "([^"]*)" catalog source with image "([^"]*)"$/) do |cs_name, cs_image|
  ensure_admin_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-marketplace" project/
  
  step %Q/admin ensures "#{cs_name}" catalog_source is deleted from the "openshift-marketplace" project after scenario/
  step %Q/I process and create:/, table(%{
    | f | #{BushSlicer::HOME}/testdata/olm/catalogsource-template.yaml |
    | p | NAME=#{cs_name}                                              |
    | p | IMAGE=#{cs_image}                                            |
  })
  raise "Error creating catalogsource" unless @result[:success]
  step %Q/a pod becomes ready with labels:/, table(%{
    | olm.catalogSource=#{cs_name} |
  })
  step %Q/I wait for the "#{cs_name}" catalog_source to become ready up to 300 seconds/
end
