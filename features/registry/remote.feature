Feature: remote registry related scenarios

  # @author pruan@redhat.com
  # @case_id OCP-11235
  @admin
  Scenario: OCP-11235 Pull image by digest value in the OpenShift registry
    Given I have a project
    And I find a bearer token of the deployer service account
    When I run the :tag client command with:
      | source_type | docker                  |
      | source      | openshift/origin:latest |
      | dest        | mystream:latest         |
    Then the step should succeed
    And evaluation of `image_stream_tag("mystream:latest").digest(user:user)` is stored in the :digest clipboard
    Given default docker-registry route is stored in the :integrated_reg_ip clipboard
    And I have a skopeo pod in the project
    And master CA is added to the "skopeo" dc
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | inspect                    |
      | --cert-dir                 |
      | /opt/qe/ca                 |
      | --creds                    |
      | dnm:<%= service_account.cached_tokens.first %>  |
      | docker://<%= cb.integrated_reg_ip %>/<%= project.name %>/mystream@<%= cb.digest %>  |
    Then the step should succeed

  # @author yinzhou@redhat.com
  # @case_id OCP-10636
  @admin
  Scenario: OCP-10636 User should be denied pushing when it does not have 'admin' role
    Given I have a project
    And default docker-registry route is stored in the :integrated_reg_ip clipboard
    And I give project view role to the second user

    Given I switch to the second user
    And evaluation of `user.cached_tokens.first` is stored in the :user2_token clipboard
    And evaluation of `cb.integrated_reg_ip + "/" + project.name + "/tc518930-busybox:local"` is stored in the :my_tag clipboard

    Given I switch to the first user
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
      | dnm:<%= cb.user2_token %>  |
      | docker://docker.io/busybox |
      | docker://<%= cb.my_tag %>  |
    Then the step should fail
    And the output should contain "not authorized"
    When I execute on the pod:
      | skopeo                                 |
      | --debug                                |
      | --insecure-policy                      |
      | copy                                   |
      | --dest-cert-dir                        |
      | /opt/qe/ca                             |
      | --dcreds                               |
      | dnm:<%= user.cached_tokens.first %>    |
      | docker://docker.io/busybox             |
      | docker://<%= cb.my_tag %>              |
    Then the step should succeed

  # @author yinzhou@redhat.com
  # @case_id OCP-11113
  @admin
  Scenario: OCP-11113 Tracking tags with imageStream spec.tag
    Given I have a project
    Given default docker-registry route is stored in the :integrated_reg_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/busybox.json |
    Then the step should succeed
    And the "busybox" image stream was created
    Given evaluation of `cb.integrated_reg_ip + "/" + project.name + "/busybox:2.0"` is stored in the :my_tag clipboard
    And I have a skopeo pod in the project
    And master CA is added to the "skopeo" dc
    When I execute on the pod:
      | skopeo                               |
      | --debug                              |
      | --insecure-policy                    |
      | copy                                 |
      | --dest-cert-dir                      |
      | /opt/qe/ca                           |
      | --dcreds                             |
      | dnm:<%= user.cached_tokens.first %>  |
      | docker://docker.io/busybox           |
      | docker://<%= cb.my_tag %>            |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | is      |
      | resource_name | busybox |
      | o             | yaml    |
    And the output is parsed as YAML
    Then the expression should be true> @result[:parsed]['status']['tags'][0]['items'][0]['dockerImageReference'] == @result[:parsed]['status']['tags'][1]['items'][0]['dockerImageReference']

  # @author yinzhou@redhat.com
  # @case_id OCP-10904
  @admin
  Scenario: OCP-10904 Support unauthenticated with registry-admin role
    Given I have a project
    When I run the :policy_add_role_to_user client command with:
      | role            | registry-admin   |
      | user name       | system:anonymous |
    Then the step should succeed
    When I run the :new_build client command with:
      | app_repo | ruby:2.5~https://github.com/sclorg/ruby-ex.git |
    Then the step should succeed
    And the "ruby-ex-1" build was created
    And the "ruby-ex-1" build completes
    Given default docker-registry route is stored in the :integrated_reg_ip clipboard
    And I have a skopeo pod in the project
    And master CA is added to the "skopeo" dc
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | inspect                    |
      | --cert-dir                 |
      | /opt/qe/ca                 |
      | docker://<%= cb.integrated_reg_ip %>/<%= project.name %>/ruby-ex:latest |
    Then the step should succeed
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | copy                       |
      | --dest-cert-dir            |
      | /opt/qe/ca                 |
      | docker://docker.io/busybox |
      | docker://<%= cb.integrated_reg_ip %>/<%= project.name %>/mystream:latest  |
    Then the step should succeed
    Given I create a new project
    And evaluation of `project.name` is stored in the :u1p2 clipboard
    When I run the :new_build client command with:
      | app_repo | ruby:2.5~https://github.com/sclorg/ruby-ex.git |
    Then the step should succeed
    And the "ruby-ex-1" build was created
    Then the "ruby-ex-1" build completes
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | inspect                    |
      | --cert-dir                 |
      | /opt/qe/ca                 |
      | docker://<%= cb.integrated_reg_ip %>/<%= cb.u1p2 %>/ruby-ex:latest |
    Then the step should fail
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | copy                       |
      | --dest-cert-dir            |
      | /opt/qe/ca                 |
      | docker://docker.io/busybox |
      | docker://<%= cb.integrated_reg_ip %>/<%= cb.u1p2 %>/mystream:latest  |
    Then the step should fail
    And the output should contain:
      | not authorized |
