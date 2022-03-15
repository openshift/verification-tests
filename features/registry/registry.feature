Feature: Testing registry

  # @author haowang@redhat.com
  # @case_id OCP-12400
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @connected
  Scenario: Prune images by command oadm_prune_images
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

  # @author xiuwang@redhat.com
  # @case_id OCP-18994
  @admin
  @4.10 @4.9
  @singlenode
  @disconnected @connected
  Scenario: Copy image to another tag via 'oc image mirror'
    Given I have a project
    Given docker config for default image registry is stored to the :dockercfg_file clipboard
    Then I run the :image_mirror client command with:
      | source_image | <%= cb.integrated_reg_ip %>/openshift/ruby:latest              |
      | dest_image   | <%= cb.integrated_reg_ip %>/<%= project.name %>/myimage:latest |
      | a            | <%= cb.dockercfg_file %>                                       |
      | insecure     | true                                                           |
    And the step should succeed
    And the output should match:
      | Mirroring completed in |
    Given the "myimage" image stream was created
    And the "myimage" image stream becomes ready

  # @author xiuwang@redhat.com
  # @case_id OCP-18998
  @admin
  @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @connected
  Scenario: Mirror multiple locations to another registry via 'oc image mirror'
    Given I have a project
    Given docker config for default image registry is stored to the :dockercfg_file clipboard
    Then I run the :image_mirror client command with:
      | source_image | quay.io/openshifttest/base-alpine:multiarch=<%= cb.integrated_reg_ip %>/<%= project.name %>/myimage1:v1        |
      | dest_image   | quay.io/openshifttest/alpine:multiarch=<%= cb.integrated_reg_ip %>/<%= project.name %>/myimage2:v1 |
      | a            | <%= cb.dockercfg_file %>                                                                                |
      | insecure     | true                                                                                                    |
    And the step should succeed
    And the output should match:
      | Mirroring completed in |
    Given the "myimage1" image stream was created
    And the "myimage2" image stream was created
    And the "myimage1" image stream becomes ready
    And the "myimage2" image stream becomes ready

  # @author wewang@redhat.com
  # @case_id OCP-23030
  @admin
  @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  Scenario: Enable must-gather object refs in image-registry cluster
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
  @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @noproxy @connected
  Scenario: Check the related log from must-gather tool
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

  # @author xiuwang@redhat.com
  # @case_id OCP-18995
  @admin
  @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @connected
  Scenario: Mirror image to another registry via 'oc image mirror'
    Given I have a project
    Given docker config for default image registry is stored to the :dockercfg_file clipboard
    Then I run the :image_mirror client command with:
      | source_image | quay.io/openshifttest/base-alpine:multiarch                |
      | dest_image   | <%= cb.integrated_reg_ip %>/<%= project.name %>/myimage:v1 |
      | a            | <%= cb.dockercfg_file %>                                   |
      | insecure     | true                                                       |
    And the step should succeed
    And the output should match:
      | Mirroring completed in |
    Given the "myimage" image stream was created
    And the "myimage" image stream becomes ready

  # @author xiuwang@redhat.com
  # @case_id OCP-29696
  @proxy
  @4.11 @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @connected
  Scenario: Use node credentials in imagestream import
    Given I have a project
    When I run the :tag client command with:
      | source           | registry.redhat.io/rhel8/mysql-80:latest |
      | dest             | mysql:8.0-el8                            |
      | reference_policy | local                                    |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | mysql-ephemeral               |
      | p        | NAMESPACE=<%= project.name %> |
    Then the step should succeed
    When a pod becomes ready with labels:
      | deployment=mysql-1 |
    When I run the :describe client command with:
      | resource | pod                |
      | l        | deployment=mysql-1 |
    And the output should match:
      | Successfully pulled image "image-registry.openshift-image-registry.svc:5000/<%= project.name %>/mysql |
    When I run the :new_app client command with:
      | docker_image | registry.redhat.io/rhscl/ruby-25-rhel7:latest     |
      | code         | https://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    And the "ruby-hello-world-1" build completed

  # @author xiuwang@redhat.com
  # @case_id OCP-29693
  @admin
  @disconnected
  @4.11 @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  Scenario: [Disconnect]Import image from a secure registry using node credentials
    Given I have a project
    And evaluation of `image_content_source_policy('image-policy-aosqe').mirror_registry(cached: false)` is stored in the :mirror_registry clipboard
    When I run the :tag client command with:
      | source           | <%= cb.mirror_registry %>rhel8/mysql-80:latest |
      | dest             | mysql:8.0-el8                                  |
      | reference_policy | local                                          |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | mysql-ephemeral               |
      | p        | NAMESPACE=<%= project.name %> |
    Then the step should succeed
    When a pod becomes ready with labels:
      | deployment=mysql-1 |
    When I run the :describe client command with:
      | resource | pod                |
      | l        | deployment=mysql-1 |
    And the output should match:
      | Successfully pulled image "image-registry.openshift-image-registry.svc:5000/<%= project.name %>/mysql |
    When I run the :import_image client command with:
      | from       | <%= cb.mirror_registry %>rhscl/ruby-25-rhel7:latest |
      | confirm    | true                                                |
      | image_name | ruby-25-rhel7:latest                                |
    Then the step should succeed

  # @author xiuwang@redhat.com
  # @case_id OCP-29706
  @admin
  @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @connected
  Scenario: Node secret takes effect when common secret is removed
    Given I have a project
    When I run the :extract admin command with:
      | resource  | secret/pull-secret |
      | namespace | openshift-config   |
      | to        | /tmp               |
      | confirm   | true               |
    Then the step should succeed
    When I run the :create_secret client command with:
      | secret_type | generic                |
      | name        | pj-secret              |
      | from_file   | /tmp/.dockerconfigjson |
    Then the step should succeed
    When I run the :tag client command with:
      | source | registry.redhat.io/rhel8/mysql-80:latest | 
      | dest   | mysql:8.0-el8                            |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | mysql-ephemeral               |
      | p        | NAMESPACE=<%= project.name %> |
    Then the step should succeed
    When a pod becomes ready with labels:
      | deployment=mysql-1 |
    When I run the :delete client command with:
      | object_type       | secret    |
      | object_name_or_id | pj-secret |
    Then the step should succeed
    When I run the :import_image client command with:
      | from             | registry.redhat.io/rhscl/ruby-25-rhel7:latest |
      | confirm          | true                                          |
      | image_name       | ruby-25-rhel7:latest                          |
      | reference-policy | local                                         |
    Then the step should succeed
