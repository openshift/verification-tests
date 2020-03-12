Feature: Testing registry

  # @author haowang@redhat.com
  # @case_id OCP-12400
  @admin
  @destructive
  Scenario: Prune images by command oadm_prune_images
    Given cluster role "system:image-pruner" is added to the "first" user
    Given I enable image-registry default route
    Given default image registry route is stored in the :registry_ip clipboard
    And I have a project
    When I run the :policy_add_role_to_user client command with:
      | role            | registry-admin   |
      | user name       | system:anonymous |
    Then the step should succeed

    Given I have a skopeo pod in the project
    And master CA is added to the "skopeo" dc
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | copy                       |
      | --dest-cert-dir            |
      | /opt/qe/ca                 |
      | docker://docker.io/aosqe/singlelayer:latest |
      | docker://<%= cb.registry_ip %>/<%= project.name %>/mystream:latest |
    Then the step should succeed
    And the "mystream:latest" image stream tag was created
    And evaluation of `image_stream_tag("mystream:latest").image_layers(user:user)` is stored in the :layers clipboard
    And evaluation of `image_stream_tag("mystream:latest").digest(user:user)` is stored in the :digest clipboard
    And I ensures "mystream" imagestream is deleted
    Given I delete the project
    And I run the :oadm_prune_images client command with:
      | keep_younger_than | 0                     |
      | confirm           | true                  |
      | registry_url      | <%= cb.registry_ip %> |
    Then the step should succeed
    And all the image layers in the :layers clipboard do not exist in the registry
    When I run the :get client command with:
      | resource | images |
    Then the step should succeed
    And the output should not contain:
      | <%= cb.digest %> |

  # @author haowang@redhat.com
  # @case_id OCP-11310
  @admin
  Scenario: Have size information for images pushed to internal registry
    Given I have a project
    And I find a bearer token of the builder service account
    And default registry service ip is stored in the :registry_ip clipboard
    And I have a skopeo pod in the project
    And master CA is added to the "skopeo" dc
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | copy                       |
      | --dest-cert-dir            |
      | /opt/qe/ca                 |
      | --dcreds                   |
      | dnm:<%= service_account.cached_tokens.first %>  |
      | docker://docker.io/aosqe/pushwithdocker19:latest |
      | docker://<%= cb.registry_ip %>/<%= project.name %>/busybox:latest  |
    Then the step should succeed
    And evaluation of `image_stream_tag("busybox:latest").digest(user:user)` is stored in the :digest clipboard
    Then I run the :describe admin command with:
      | resource | image            |
      | name     | <%= cb.digest %> |
    And the output should match:
      | Image Size:.* |

  # @author xiuwang@redhat.com
  # @case_id OCP-18994
  @admin
  Scenario: Copy image to another tag via 'oc image mirror'
    Given I have a project
    Given docker config for default image registry is stored to the :dockercfg_file clipboard
    Then I run the :image_mirror client command with:
      | source_image | <%= cb.integrated_reg_ip %>/openshift/ruby:2.5                 |
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
  Scenario: Mirror multiple locations to another registry via 'oc image mirror'
    Given I have a project
    Given docker config for default image registry is stored to the :dockercfg_file clipboard
    Then I run the :image_mirror client command with:
      | source_image | docker.io/library/busybox:latest=<%= cb.integrated_reg_ip %>/<%= project.name %>/myimage1:v1 |
      | dest_image   | centos/ruby-25-centos7:latest=<%= cb.integrated_reg_ip %>/<%= project.name %>/myimage2:v1    |
      | a            | <%= cb.dockercfg_file %>                                                                     |
      | insecure     | true                                                                                         |
    And the step should succeed
    And the output should match:
      | Mirroring completed in |
    Given the "myimage1" image stream was created
    And the "myimage2" image stream was created
    And the "myimage1" image stream becomes ready
    And the "myimage2" image stream becomes ready

  # @author xiuwang@redhat.com
  # @case_id OCP-18995
  @admin
  Scenario: Mirror image to another registry via 'oc image mirror'
    Given I have a project
    Given docker config for default image registry is stored to the :dockercfg_file clipboard
    Then I run the :image_mirror client command with:
      | source_image | centos/ruby-22-centos7:latest                              |
      | dest_image   | <%= cb.integrated_reg_ip %>/<%= project.name %>/myimage:v1 |
      | a            | <%= cb.dockercfg_file %>                                   | 
      | insecure     | true                                                       |
    And the step should succeed
    And the output should match:
      | Mirroring completed in |
    Given the "myimage" image stream was created
    And the "myimage" image stream becomes ready
