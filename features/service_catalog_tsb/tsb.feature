Feature: Template service broker related features

  # @author zitang@redhat.com
  # @case_id OCP-21690
  @admin
  @inactive
  Scenario: OCP-21690:OperatorSDK Clusterserviceclass and clusterserviceplan of templateinstance were created
    Given admin checks that the "template-service-broker" cluster_service_broker exists
    When I run the :get client command with:
      | resource | clusterserviceplan                                                      |
      | o        | custom-columns=NAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName,BROKER:.spec.clusterServiceBrokerName |
    Then the output should contain "template-service-broker"
    Given cluster service classes are indexed by external name in the :csc clipboard
    Then the expression should be true> cb.csc.values.find {|c| c.cluster_svc_broker_name == "template-service-broker"}
