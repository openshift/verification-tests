Feature: remote registry related scenarios

  # @author yinzhou@redhat.com
  # @case_id OCP-10904
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10904:ImageRegistry Support unauthenticated with registry-admin role
    Given I have a project
    Given I find a bearer token of the default service account
    When I run the :policy_add_role_to_user client command with:
      | role            | registry-admin   |
      | user name       | system:anonymous |
    Then the step should succeed
    When I run the :new_build client command with:
      | app_repo | registry.redhat.io/ubi8/ruby-30:latest~https://github.com/sclorg/ruby-ex.git |
    Then the step should succeed
    And the "ruby-ex-1" build was created
    And the "ruby-ex-1" build completes
    Given default registry service ip is stored in the :integrated_reg_ip clipboard
    And I have a skopeo pod in the project
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | inspect                    |
      | --tls-verify=false         |
      | --creds                    |
      | <%= service_account.cached_tokens.first %>                              |
      | docker://<%= cb.integrated_reg_ip %>/<%= project.name %>/ruby-ex:latest |
    Then the step should succeed
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | copy                       |
      | --dest-tls-verify=false    |
      | --dcreds                   |
      | <%= service_account.cached_tokens.first %>                                |
      | docker://quay.io/openshifttest/base-alpine:multiarch                      |
      | docker://<%= cb.integrated_reg_ip %>/<%= project.name %>/mystream:latest  |
    Then the step should succeed
    Given I create a new project
    And evaluation of `project.name` is stored in the :u1p2 clipboard
    When I run the :new_build client command with:
      | app_repo | registry.redhat.io/ubi8/ruby-30:latest~https://github.com/sclorg/ruby-ex.git |
    Then the step should succeed
    And the "ruby-ex-1" build was created
    Then the "ruby-ex-1" build completes
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | inspect                    |
      | --tls-verify=false         |
      | --creds                    |
      | <%= service_account.cached_tokens.first %>                         |
      | docker://<%= cb.integrated_reg_ip %>/<%= cb.u1p2 %>/ruby-ex:latest |
    Then the step should fail
    And the output should contain:
      | unauthorized |
    When I execute on the pod:
      | skopeo                     |
      | --debug                    |
      | --insecure-policy          |
      | copy                       |
      | --dest-tls-verify=false    |
      | <%= service_account.cached_tokens.first %>                           |
      | docker://quay.io/openshifttest/base-alpine:multiarch                 |
      | docker://<%= cb.integrated_reg_ip %>/<%= cb.u1p2 %>/mystream:latest  |
    Then the step should fail
