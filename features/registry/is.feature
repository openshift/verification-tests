Feature: Testing imagestream

  # @author yinzhou@redhat.com
  # @case_id OCP-13895
  @destructive
  @admin
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  Scenario: OCP-13895:ImageRegistry Should prune the extenal image correctly
    Given default registry service ip is stored in the :registry_hostname clipboard
    Given I have a project
    And I have a skopeo pod in the project
    And master CA is added to the "skopeo" dc
    When I run the :tag client command with:
      | source_type | docker                                      |
      | source      | quay.io/openshifttest/base-alpine:1.2.0 |
      | dest        | myis13895:latest                            |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role            | registry-admin   |
      | user name       | system:anonymous |
    Then the step should succeed
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | inspect                    |
      | --cert-dir                 |
      | /opt/qe/ca                 |
      | docker://<%= cb.registry_hostname %>/<%= project.name %>/myis13895:latest  |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | istag                    |
      | resource_name | myis13895:latest         |
      | template      | {{.image.metadata.name}} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :digest1 clipboard
    When I run the :tag client command with:
      | source_type  | docker                    |
      | source       | openshift/hello-openshift |
      | dest         | myis13895:latest          |
    Then the step should succeed
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | inspect                    |
      | --cert-dir                 |
      | /opt/qe/ca                 |
      | docker://<%= cb.registry_hostname %>/<%= project.name %>/myis13895:latest  |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | istag                    |
      | resource_name | myis13895:latest         |
      | template      | {{.image.metadata.name}} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :digest2 clipboard
    When I run the :tag client command with:
      | source_type  | docker                       |
      | source       | openshift/deployment-example |
      | dest         | myis13895:latest             |
    Then the step should succeed
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | inspect                    |
      | --cert-dir                 |
      | /opt/qe/ca                 |
      | docker://<%= cb.registry_hostname %>/<%= project.name %>/myis13895:latest  |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | istag                    |
      | resource_name | myis13895:latest         |
      | template      | {{.image.metadata.name}} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :digest3 clipboard
    Given cluster role "system:image-pruner" is added to the "first" user
    And I run the :oadm_prune_images client command with:
      | keep_tag_revisions | 1                           |
      | keep_younger_than  | 0                           |
      | registry_url       | <%= cb.registry_hostname %> |
      | confirm            | true                        |
    Then the step should succeed
    And the output should not contain:
      | <%= cb.digest3 %> |
    And the output should contain:
      | <%= cb.digest1 %> |
      | <%= cb.digest2 %> |
