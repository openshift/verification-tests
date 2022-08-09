Feature: Testing imagestream

  # @author yinzhou@redhat.com
  # @case_id OCP-13895
  @destructive
  @admin
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  Scenario: OCP-13895:ImageRegistry Should prune the extenal image correctly
    Given default registry service ip is stored in the :registry_hostname clipboard
    Given I have a project
    And I have a skopeo pod in the project
    And master CA is added to the "skopeo" dc
    When I run the :tag client command with:
      | source_type | docker                                      |
      | source      | quay.io/openshifttest/base-alpine:multiarch |
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

  # @author xiuwang@redhat.com
  # @case_id OCP-19196
  @destructive
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-19196:ImageRegistry Prune images when DC reference to invalid image
    Given I have a project
    Given I enable image-registry default route
    Given default image registry route is stored in the :registry_hostname clipboard
    Given certification for default image registry is stored to the :reg_crt_name clipboard
    When I run the :new_app_as_dc client command with:
      | app_repo | quay.io/openshifttest/ruby-27:multiarch~https://github.com/sclorg/ruby-ex.git |
    Then the step should succeed
    And I wait for the "ruby-27:multiarch" image_stream_tag to appear
    And the "ruby-ex-1" build was created
    And the "ruby-ex-1" build completes
    When I run the :patch client command with:
      | resource      | dc                                              |
      | resource_name | ruby-ex                                         |
      | p             | {"spec":{"triggers":[{"type":"ConfigChange"}]}} |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | dc                                                                                                                                                |
      | resource_name | ruby-ex                                                                                                                                           |
      | p             | {"spec":{"template":{"spec":{"containers":[{"image":"<%= cb.registry_hostname %>/<%= project.name %>/ruby-ex@sha256:nonono","name":"ruby-ex"}]}}}}|
    Given cluster role "system:image-pruner" is added to the "first" user
    And I run the :oadm_prune_images client command with:
      | keep_tag_revisions | 1                           |
      | keep_younger_than  | 0                           |
      | registry_url       | <%= cb.registry_hostname %> |
      | confirm            | true                        |
      | ca                 | <%= cb.reg_crt_name %>      |
    Then the step should fail
    And the output should contain:
      | invalid |
    And I run the :oadm_prune_images client command with:
      | keep_tag_revisions  | 1                           |
      | keep_younger_than   | 0                           |
      | registry_url        | <%= cb.registry_hostname %> |
      | confirm             | true                        |
      | ca                  | <%= cb.reg_crt_name %>      |
      | ignore_invalid_refs | true                        |
    Then the step should succeed

  # @author xiuwang@redhat.com
  # @case_id OCP-16495
  @destructive
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-16495:ImageRegistry Do not prune layer of a valid Image due to minimum aging
    Given I have a project
    Given I enable image-registry default route
    Given default image registry route is stored in the :registry_hostname clipboard
    Given certification for default image registry is stored to the :reg_crt_name clipboard

    When I run the :new_app client command with:
      | app_repo | quay.io/openshifttest/ruby-27@sha256:cdb6a13032184468b1e0607f36cfb8834c97dbeffeeff800e9e6834323bed8fc~https://github.com/sclorg/ruby-ex.git |
    Then the step should succeed
    Given the "ruby-27" image stream was created 
    Given the "ruby-27" image stream becomes ready 
    And the "ruby-ex-1" build was created
    And the "ruby-ex-1" build completes
    And the "ruby-ex:latest" image stream tag was created
    And evaluation of `image_stream_tag("ruby-ex:latest").digest(user:user)` is stored in the :digest1 clipboard
    Given 120 seconds have passed
    And the project is deleted

    Given I create a new project
    When I run the :new_app client command with:
      | app_repo | quay.io/openshifttest/ruby-27:multiarch~https://github.com/sclorg/ruby-ex.git |
    Then the step should succeed
    And I wait for the "ruby-27:multiarch" image_stream_tag to appear
    And the "ruby-ex-1" build was created
    And the "ruby-ex-1" build completes
    And the "ruby-ex:latest" image stream tag was created
    And evaluation of `image_stream_tag("ruby-ex:latest").digest(user:user)` is stored in the :digest2 clipboard
    Given the project is deleted

    Given cluster role "system:image-pruner" is added to the "first" user
    And I run the :oadm_prune_images client command with:
      | keep_younger_than | 2m                          |
      | registry_url      | <%= cb.registry_hostname %> |
      | confirm           | true                        |
      | ca                | <%= cb.reg_crt_name %>      |
    Then the step should succeed
    And the output should contain:
      | <%= cb.digest1 %> |
    And the output should not contain:
      | <%= cb.digest2 %> |
