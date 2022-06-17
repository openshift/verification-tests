Feature: Template service broker related features

  # @author zitang@redhat.com
  # @case_id OCP-21690
  @admin
  Scenario: [CVP] Clusterserviceclass and clusterserviceplan of templateinstance were created 
    Given admin checks that the "template-service-broker" cluster_service_broker exists
    When I run the :get client command with:
      | resource | clusterserviceplan                                                      |
      | o        | custom-columns=NAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName,BROKER:.spec.clusterServiceBrokerName |
    Then the output should contain "template-service-broker"
    Given cluster service classes are indexed by external name in the :csc clipboard
    Then the expression should be true> cb.csc.values.find {|c| c.cluster_svc_broker_name == "template-service-broker"}

  # @author zitang@redhat.com
  # @case_id OCP-14477
  @admin
  Scenario: OCP-14477 Provision a templateinstance 
    Given I have a project
    # Provision jenkins instance
    When I process and create:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/serviceinstance-template.yaml |
      | p | INSTANCE_NAME=jenkins-ephemeral          |
      | p | CLASS_EXTERNAL_NAME=jenkins-ephemeral    |
      | p | SECRET_NAME=jenkins-ephemeral-parameters |
      | p | INSTANCE_NAMESPACE=<%= project.name %>   |
    Then the step should succeed
    And evaluation of `service_instance("jenkins-ephemeral").uid(user: user)` is stored in the :jenkins_uid clipboard
    When I process and create:
      | f  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/serviceinstance-parameters-template.yaml |
      | p | SECRET_NAME=jenkins-ephemeral-parameters |
      | p | INSTANCE_NAME=jenkins-ephemeral          |
      | p | PARAMETERS={"DISABLE_ADMINISTRATIVE_MONITORS":"false","ENABLE_OAUTH":"true","JENKINS_IMAGE_STREAM_TAG":"jenkins:2","JENKINS_SERVICE_NAME":"jenkins","JNLP_SERVICE_NAME":"jenkins-jnlp","MEMORY_LIMIT":"512Mi","NAMESPACE":"openshift"} |
      | p | UID=<%= cb.jenkins_uid %>                |
      | n | <%= project.name %>                      |
    Then the step should succeed
    And I wait for all service_instance in the project to become ready up to 360 seconds
    And a pod becomes ready with labels:
      | deploymentconfig=jenkins |

    # Create servicebinding of DB apb
    When I process and create:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/servicebinding-template.yaml |
      | p | BINDING_NAME=jenkins-binding               |
      | p | INSTANCE_NAME=jenkins-ephemeral            |
      | p | SECRET_NAME=jenkins-ephemeral-credentials  |
      | n | <%= project.name %>                        |
    Then the step should succeed
    And I wait for the "jenkins-binding" service_binding to become ready up to 60 seconds

    # delete servicebinding and serviceinstance
    Given I ensure "jenkins-binding" service_binding is deleted
    And I wait for the resource "secret" named "jenkins-ephemeral-credentials" to disappear within 120 seconds
    Given I ensure "jenkins-ephemeral" service_instance is deleted
    And I wait for the resource "dc" named "jenkins" to disappear within 120 seconds
