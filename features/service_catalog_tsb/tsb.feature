Feature: Template service broker related features

  # @author zitang@redhat.com
  # @case_id OCP-21690
  @admin
  Scenario: [CVP] Clusterserviceclass and clusterserviceplan of templateinstance were created 
    Given admin checks that the "template-service-broker" cluster_service_broker exists
    When I run the :get client command with:
      | resource | clusterserviceclass                                                       |
      | o        | custom-columns=NAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName,BROKER:.spec.clusterServiceBrokerName |
    Then the output should contain "template-service-broker"
    When I run the :get client command with:
      | resource | clusterserviceplan                                                      |
      | o        | custom-columns=NAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName,BROKER:.spec.clusterServiceBrokerName |
    Then the output should contain "template-service-broker"
