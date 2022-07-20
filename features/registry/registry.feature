Feature: Testing registry

  # @author haowang@redhat.com
  # @case_id OCP-12400
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-12400:ImageRegistry Prune images by command oadm_prune_images
    Given cluster role "system:image-pruner" is added to the "first" user
    Given I enable image-registry default route
    Given default image registry route is stored in the :registry_ip clipboard
    And I have a project
    When I run the :policy_add_role_to_user client command with:
      | role            | registry-admin   |
      | user name       | system:anonymous |
    Then the step should succeed

    When I run the :import_image client command with:
      | from       | quay.io/openshifttest/base-alpine:multiarch |
      | confirm    | true                                        |
      | image_name | mystream                                    |
    Then the step should succeed
    And the "mystream:latest" image stream tag was created
    And evaluation of `image_stream_tag("mystream:latest").image_layers(user:user)` is stored in the :layers clipboard
    And evaluation of `image_stream_tag("mystream:latest").digest(user:user)` is stored in the :digest clipboard
    And I ensure "mystream" imagestream is deleted
    Given I delete the project
    And I run the :oadm_prune_images client command with:
      | keep_younger_than | 0                     |
      | confirm           | true                  |
      | registry_url      | <%= cb.registry_ip %> |
    Then the step should succeed
    When I run the :get client command with:
      | resource | images |
    Then the step should succeed
    And the output should not contain:
      | <%= cb.digest %> |

  # @author wewang@redhat.com
  # @case_id OCP-23030
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-23030:ImageRegistry Enable must-gather object refs in image-registry cluster
    When I run the :get admin command with:
      | resource      | co             |
      | resource_name | image-registry |
      | o             | yaml           |
    Then the step should succeed
    And the output should match:
      | name: system:registry                         |
      | resource: clusterroles                        |
      | name: registry-registry-role                  |
      | resource: clusterrolebindings                 |
      | (name: registry)?                             |
      | (resource: serviceaccounts)?                  |
      | (name: image-registry-certificates)?          |
      | (resource: configmaps)?                       |
      | (name: image-registry-private-configuration)? |
      | (resource: secrets)?                          |
      | (name: image-registry)?                       |
      | (resource: services)?                         |
      | (name: node-ca)?                              |
      | (resource: daemonsets)?                       |
      | (resource: deployments)?                      |
    When I run the :get admin command with:
      | resource      | clusterroles    |
      | resource_name | system:registry |
    Then the step should succeed
    When I run the :get admin command with:
      | resource      | clusterrolebindings    |
      | resource_name | registry-registry-role |
    Then the step should succeed
    When I run the :get admin command with:
      | resource      | serviceaccounts          |
      | resource_name | registry                 |
      | namespace     | openshift-image-registry |
    Then the step should succeed
    When I run the :get admin command with:
      | resource      | configmaps                  |
      | resource_name | image-registry-certificates |
      | namespace     | openshift-image-registry    |
    Then the step should succeed
    When I run the :get admin command with:
      | resource      | secrets                              |
      | resource_name | image-registry-private-configuration |
      | namespace     | openshift-image-registry             |
    Then the step should succeed
    When I run the :get admin command with:
      | resource      | ds                        |
      | resource_name | node-ca                   |
      | namespace     | openshift-image-registry  |
    Then the step should succeed
    When I run the :get admin command with:
      | resource      | service                   |
      | resource_name | image-registry            |
      | namespace     | openshift-image-registry  |
    Then the step should succeed
    When I run the :get admin command with:
      | resource      | service                   |
      | resource_name | image-registry            |
      | namespace     | openshift-image-registry  |
    Then the step should succeed
    When I run the :get admin command with:
      | resource      | deployments               |
      | resource_name | image-registry            |
      | namespace     | openshift-image-registry  |
    Then the step should succeed

  # @author wewang@redhat.com
  # @case_id OCP-23063
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-23063:ImageRegistry Check the related log from must-gather tool
    When I run the :delete admin command with:
      | object_type       | co             |
      | object_name_or_id | image-registry |
    Then the step should succeed
    When I run the :oadm_inspect admin command with:
      | resource_type | co             |
      | resource_name | image-registry |
    Then the step should succeed
    And the output should match:
      | Gathering data for ns/openshift-image-registry... |
      | Wrote inspect data to inspect.local.*             |
