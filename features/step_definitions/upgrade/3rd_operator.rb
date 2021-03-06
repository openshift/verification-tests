# Enable Service Catalog
Given /^enable service catalog$/ do
  ensure_admin_tagged
  step %Q/I run the :get client command with:/, table(%{
    | resource       | clusterservicebroker |
  })
  unless @result[:success]
    logger.info("### start to enable the Service Catalog")
    step %Q/I run the :patch client command with:/, table(%{
      | resource      | ServiceCatalogAPIServer                 |
      | resource_name | cluster                                 |
      | p             | {"spec":{"managementState": "Managed"}} |
      | type          | merge                                   |
    })
    raise "Failed to enable the ServiceCatalogAPIServer" unless @result[:success]

    step %Q/I run the :patch client command with:/, table(%{
      | resource      | ServiceCatalogControllerManager         |
      | resource_name | cluster                                 |
      | p             | {"spec":{"managementState": "Managed"}} |
      | type          | merge                                   |
    })
    raise "Failed to enable the ServiceCatalogControllerManager" unless @result[:success]
  end
end

# Subscribe the 3rd level operator according to the channel
Given /^optional operator "([^"]*)" from channel "([^"]*)" is subscribed in "([^"]*)" project$/ do | name, channel, proj_name|
  transform binding, :name, :channel, :proj_name
    ensure_admin_tagged
    step %Q/I switch to cluster admin pseudo user/
    step %Q/I use the "#{proj_name}" project/
    unless operator_group('test-og').exists?
      # Create operator group in this namespace
      operator_group_yaml ||= "#{BushSlicer::HOME}/testdata/olm/operatorgroup-template.yaml"
      step %Q/I process and create:/, table(%{
        | f | #{operator_group_yaml} |
        | p | NAME=test-og         |
        | p | NAMESPACE=#{proj_name} |
      })
      raise "Error creating OperatorGroup: test-og" unless @result[:success]
    end
    logger.info("### operator group: test-og is installed successfully in #{proj_name} namespace")

    unless subscription("#{name}").exists?
      # Subscribe etcd operator
      sub_yaml ||= "#{BushSlicer::HOME}/testdata/olm/subscription-template.yaml"
      step %Q/I process and create:/, table(%{
        | f | #{sub_yaml}                           |
        | p | NAME=#{name}-sub                      |
        | p | NAMESPACE=#{proj_name}                |
        | p | CHANNEL=#{channel}                    |
        | p | PACKAGE=#{name}                       |
      })
      raise "Error creating subscription: #{name}-sub" unless @result[:success]
    end
    logger.info("### optional operator: #{name} is subscribed successfully in #{proj_name} namespace")
end
