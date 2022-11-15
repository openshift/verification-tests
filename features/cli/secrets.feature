Feature: secrets related scenarios

  # @author yinzhou@redhat.com
  # @case_id OCP-10725
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10725:Workloads deployment hook volume inheritance --with secret volume
    Given I have a project
    And I run the :create_secret client command with:
      | secret_type | generic    |
      | name        | my-secret  |
      | from_file   | /etc/hosts |
    Then the step should succeed
    Given I obtain test data file "deployment/ocp10725/hook-inheritance-secret-volume.json"
    When I run the :create client command with:
      | f | hook-inheritance-secret-volume.json |
    Then the step should succeed
  ## mount should be correct to the pod, no-matter if the pod is completed or not, check the case checkpoint
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource  | pod  |
      | resource_name | hooks-1-hook-pre |
      |  o        | yaml |
    Then the output by order should match:
      | - mountPath: /opt1    |
      | name: secret          |
      | secretName: my-secret |
    """

  # @author qwang@redhat.com
  # @case_id OCP-12281
  @smoke
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-12281:Node Pods do not have access to each other's secrets in the same namespace
    Given I have a project
    Given I obtain test data file "secrets/ocp12281/first-secret.json"
    When I run the :create client command with:
      | filename | first-secret.json |
    Given I obtain test data file "secrets/ocp12281/second-secret.json"
    And I run the :create client command with:
      | filename | second-secret.json |
    Then the step should succeed
    Given I obtain test data file "secrets/ocp12281/first-secret-pod.yaml"
    When I run the :create client command with:
      | filename | first-secret-pod.yaml |
    Given I obtain test data file "secrets/ocp12281/second-secret-pod.yaml"
    And I run the :create client command with:
      | filename | second-secret-pod.yaml |
    Then the step should succeed
    Given the pod named "first-secret-pod" status becomes :running
    When I run the :exec client command with:
      | pod              | first-secret-pod            |
      | exec_command     | cat                         |
      | exec_command_arg | /etc/secret-volume/username |
    Then the output should contain:
      | first-username |
    When I run the :exec client command with:
      | pod              | first-secret-pod            |
      | exec_command     | cat                         |
      | exec_command_arg | /etc/secret-volume/password |
    Then the output should contain:
      | password-first |
    Given the pod named "second-secret-pod" status becomes :running
    When I run the :exec client command with:
      | pod              | second-secret-pod           |
      | exec_command     | cat                         |
      | exec_command_arg | /etc/secret-volume/username |
    Then the output should contain:
      | second-username |
    When I run the :exec client command with:
      | pod              | second-secret-pod           |
      | exec_command     | cat                         |
      | exec_command_arg | /etc/secret-volume/password |
    Then the output should contain:
      | password-second |

  # @author qwang@redhat.com
  # @case_id OCP-12310
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-12310:Node Pods do not have access to each other's secrets with the same secret name in different namespaces
    Given I have a project
    Given evaluation of `project.name` is stored in the :project0 clipboard
    Given I obtain test data file "secrets/secret1.json"
    When I run the :create client command with:
      | filename  | secret1.json |
    Given I obtain test data file "secrets/secret-pod-1.yaml"
    And I run the :create client command with:
      | filename  | secret-pod-1.yaml |
    Then the step should succeed
    And the pod named "secret-pod-1" status becomes :running
    When I create a new project
    Given evaluation of `project.name` is stored in the :project1 clipboard
    Given I obtain test data file "secrets/secret2.json"
    And I run the :create client command with:
      | filename  | secret2.json |
    Given I obtain test data file "secrets/secret-pod-2.yaml"
    And I run the :create client command with:
      | filename  | secret-pod-2.yaml |
    Then the step should succeed
    And the pod named "secret-pod-2" status becomes :running
    When I run the :exec client command with:
      | pod              | secret-pod-2                  |
      | exec_command     | cat                           |
      | exec_command_arg | /etc/secret-volume-2/password |
      | namespace        | <%= cb.project1 %>            |
    Then the output should contain:
      | password-second |
    When I use the "<%= cb.project0 %>" project
    When I run the :exec client command with:
      | pod              | secret-pod-1                  |
      | exec_command     | cat                           |
      | exec_command_arg | /etc/secret-volume-1/username |
      | namespace        | <%= cb.project0 %>            |
    Then the output should contain:
      | first-username |

  # @author yantan@redhat.com
  @proxy
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Insert secret to builder container via oc new-build - source/docker build
    Given I have a project
    Given I obtain test data file "secrets/testsecret1.json"
    When I run the :create client command with:
      | f | testsecret1.json |
    Then the step should succeed
    Given I obtain test data file "secrets/testsecret2.json"
    When I run the :create client command with:
      | f | testsecret2.json |
    Then the step should succeed
    When I run the :new_build client command with:
      | docker_image | centos/ruby-22-centos7:latest                |
      | app_repo     | https://github.com/openshift-qe/build-secret |
      | strategy     | <type>         |
      | build_secret | <build_secret> |
      | build_secret | testsecret2    |
    Then the step should succeed
    Given I obtain test data file "deployment/ocp11947/test.json"
    When I run the :create client command with:
      | f | test.json |
    Then the step should succeed
    Given the "build-secret-1" build was created
    And the "build-secret-1" build completed
    Given the pod named "build-secret-1-hook-pre" becomes present
    Given the pod named "build-secret-1-hook-pre" status becomes :running
    When I run the :exec client command with:
      | pod | build-secret-1-hook-pre |
      | exec_command | <command> |
      | exec_command_arg | <path>/secret1 |
      | exec_command_arg | <path>/secret2 |
      | exec_command_arg | <path>/secret3 |
      | exec_command_arg | /opt/app-root/src/secret1 |
      | exec_command_arg | /opt/app-root/src/secret2 |
      | exec_command_arg | /opt/app-root/src/secret3 |
    Then the step should succeed
    And the expression should be true> <expression>

    @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
    @upgrade-sanity
    @singlenode
    @noproxy @connected
    @network-ovnkubernetes @network-openshiftsdn
    @heterogeneous @arm64 @amd64
    @inactive
    Examples:
      | case_id            | type   | build_secret          | path      | command | expression |
      | OCP-11947:BuildAPI | docker | testsecret1:mysecret1 | mysecret1 | ls      | true       | # @case_id OCP-11947

  # @author chezhang@redhat.com
  # @case_id OCP-10814
  @smoke
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10814:Node Consume the same Secrets as environment variables in multiple pods
    Given I have a project
    Given I obtain test data file "secrets/secret.yaml"
    When I run the :create client command with:
      | f | secret.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret   |
      | name     | test-secret |
    Then the output should match:
      | data-1:\\s+9\\s+bytes  |
      | data-2:\\s+11\\s+bytes |
    Given I obtain test data file "job/job-secret-env.yaml"
    When I run the :create client command with:
      | f | job-secret-env.yaml |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource | pods |
    Then the step should succeed
    And the output should contain 3 times:
      |  secret-env- |
    """
    Given status becomes :succeeded of exactly 3 pods labeled:
      | app=test |
    Then the step should succeed
    And I wait until job "secret-env" completes
    When I run the :logs client command with:
      | resource_name | <%= pod(-3).name %> |
    Then the step should succeed
    And the output should contain:
      | MY_SECRET_DATA_1=value-1 |
      | MY_SECRET_DATA_2=value-2 |
    When I run the :logs client command with:
      | resource_name | <%= pod(-2).name %> |
    Then the step should succeed
    And the output should contain:
      | MY_SECRET_DATA_1=value-1 |
      | MY_SECRET_DATA_2=value-2 |
    When I run the :logs client command with:
      | resource_name | <%= pod(-1).name %> |
    Then the step should succeed
    And the output should contain:
      | MY_SECRET_DATA_1=value-1 |
      | MY_SECRET_DATA_2=value-2 |

  # @author chezhang@redhat.com
  # @case_id OCP-11260
  @smoke
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-11260:Node Using Secrets as Environment Variables
    Given I have a project
    Given I obtain test data file "secrets/secret.yaml"
    When I run the :create client command with:
      | f | secret.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret   |
      | name     | test-secret |
    Then the output should match:
      | data-1:\\s+9\\s+bytes  |
      | data-2:\\s+11\\s+bytes |
    Given I obtain test data file "secrets/secret-env-pod.yaml"
    When I run the :create client command with:
      | f | secret-env-pod.yaml |
    Then the step should succeed
    And the pod named "secret-env-pod" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | secret-env-pod |
    Then the step should succeed
    And the output should contain:
      | MY_SECRET_DATA=value-1 |

  # @author qwang@redhat.com
  # @case_id OCP-11311
  @smoke
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  Scenario: OCP-11311:Node Secret volume should update when secret is updated
    Given I have a project
    Given I obtain test data file "secrets/secret1.json"
    When I run the :create client command with:
      | f | secret1.json |
    Then the step should succeed
    Given I obtain test data file "secrets/secret-pod-1.yaml"
    When I run the :create client command with:
      | f | secret-pod-1.yaml |
    Then the step should succeed
    Given the pod named "secret-pod-1" status becomes :running
    When I run the :exec client command with:
      | pod              | secret-pod-1                  |
      | exec_command     | cat                           |
      | exec_command_arg | /etc/secret-volume-1/username |
    Then the output should contain:
      | first-username |
    When I run the :patch client command with:
      | resource      | secret                                                   |
      | resource_name | secret-n                                                 |
      | p             | {"data":{"username":"Zmlyc3QtdXNlcm5hbWUtdXBkYXRlCg=="}} |
    Then the step should succeed
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :exec client command with:
      | pod              | secret-pod-1                  |
      | exec_command     | cat                           |
      | exec_command_arg | /etc/secret-volume-1/username |
    Then the output should contain:
      | first-username-update |
    """
    Then the step should succeed

  # @author qwang@redhat.com
  # @case_id OCP-10899
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10899:Node Mapping specified secret volume should update when secret is updated
    Given I have a project
    Given I obtain test data file "secrets/secret1.json"
    When I run the :create client command with:
      | f | secret1.json |
    Then the step should succeed
    Given I obtain test data file "secrets/mapping-secret-volume-pod.yaml"
    When I run the :create client command with:
      | f | mapping-secret-volume-pod.yaml |
    Then the step should succeed
    Given the pod named "mapping-secret-volume-pod" status becomes :running
    When I execute on the pod:
      | cat | /etc/secret-volume/test-secrets |
    Then the step should succeed
    And the output should contain:
      | first-username |
    When I run the :patch client command with:
      | resource      | secret                                                   |
      | resource_name | secret-n                                                 |
      | p             | {"data":{"username":"Zmlyc3QtdXNlcm5hbWUtdXBkYXRlCg=="}} |
    Then the step should succeed
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat | /etc/secret-volume/test-secrets |
    Then the output should contain:
      | first-username-update |
    """
    Then the step should succeed

  # @author qwang@redhat.com
  # @case_id OCP-10569
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10569:Node Allow specifying secret data using strings and images
    Given I have a project
    Given I obtain test data file "secrets/secret-datastring-image.json"
    When I run the :create client command with:
      | f | secret-datastring-image.json |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret                  |
      | name     | secret-datastring-image |
    Then the output should match:
      | image:\\s+7059\\s+bytes |
      | password:\\s+5\\s+bytes |
      | username:\\s+5\\s+bytes |
    Given I obtain test data file "secrets/pod-secret-datastring-image-volume.yaml"
    When I run the :create client command with:
      | f | pod-secret-datastring-image-volume.yaml |
    Then the step should succeed
    Given the pod named "pod-secret-datastring-image-volume" status becomes :running
    When I execute on the pod:
      | cat | /etc/secret-volume/username |
    Then the step should succeed
    And the output should contain:
      | hello |
    When I run the :patch client command with:
      | resource      | secret                           |
      | resource_name | secret-datastring-image          |
      | p             | {"stringData":{"username":"foobar"}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret                  |
      | name     | secret-datastring-image |
    Then the output should match:
      | image:\\s+7059\\s+bytes |
      | password:\\s+5\\s+bytes |
      | username:\\s+6\\s+bytes |
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat | /etc/secret-volume/username |
    Then the output should contain:
      | foobar |
    """
    Then the step should succeed

  # @author xiuwang@redhat.com
  # @case_id OCP-10982
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-10982:BuildAPI oc new-app to gather git creds
    Given I have a project
    When I have an http-git service in the project
    And I run the :set_env client command with:
      | resource | dc/git                            |
      | e        | REQUIRE_SERVER_AUTH=              |
      | e        | REQUIRE_GIT_AUTH=openshift:redhat |
      | e        | BUILD_STRATEGY=source             |
      | e        | ALLOW_ANON_GIT_PULL=false         |
    Then the step should succeed
    When a pod becomes ready with labels:
      | deploymentconfig=git |
      | deployment=git-2     |
    And I execute on the pod:
      | sh                                                                                                      |
      | -c                                                                                                      |
      | cd /var/lib/git/ && git clone --bare https://github.com/openshift/ruby-hello-world ruby-hello-world.git |
    Then the step should succeed
    When I run the :new_app client command with:
      | app_repo | ruby~http://<%= cb.git_route %>/ruby-hello-world.git |
    Then the step should succeed
    When I run the :create_secret client command with:
      | name         | mysecret           |
      | secret_type  | generic            |
      | from_literal | username=openshift |
      | from_literal | password=redhat    |
    Then the step should succeed
    When I run the :secret_link client command with:
      | secret_name | mysecret  |
      | sa_name     | builder   |
    Then the step should succeed
    And I run the :set_build_secret client command with:
      | bc_name     | ruby-hello-world |
      | secret_name | mysecret         |
      | source      | true             |
    Then the step should succeed
    Given the "ruby-hello-world-1" build fails
    And I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-2" build completed
    When I run the :delete client command with:
      | all_no_dash ||
      | all         ||
    Then the step should succeed

    When I have an ssh-git service in the project
    And the "secret" file is created with the following lines:
      | <%= cb.ssh_private_key.to_pem %> |
    And I run the :create_secret client command with:
      | secret_type | generic               |
      | name        | sshsecret             |
      | from_file   | ssh-privatekey=secret |
    Then the step should succeed
    Then the step should succeed
    When I execute on the pod:
      | bash                                                                                                         |
      | -c                                                                                                           |
      | cd /repos/ && rm -rf sample.git && git clone --bare https://github.com/openshift/ruby-hello-world sample.git |
    Then the step should succeed
    When I run the :new_app client command with:
      | app_repo |ruby~<%= cb.git_repo %>|
    Then the step should succeed
    When I run the :secret_link client command with:
      | secret_name | sshsecret |
      | sa_name     | builder   |
    Then the step should succeed
    And I run the :set_build_secret client command with:
      | secret_name | sshsecret |
      | bc_name     | sample    |
      | source      | true      |
    Then the step should succeed
    Given the "sample-1" build fails
    And I run the :start_build client command with:
      | buildconfig | sample |
    Then the step should succeed
    And the "sample-2" build completed

  # @author xiuwang@redhat.com
  # @case_id OCP-12838
  @inactive
  Scenario: OCP-12838:BuildAPI Use build source secret based on annotation on Secret --http
    Given I have a project
    When I have an http-git service in the project
    And I run the :set_env client command with:
      | resource | dc/git                            |
      | e        | REQUIRE_SERVER_AUTH=              |
      | e        | REQUIRE_GIT_AUTH=openshift:redhat |
      | e        | BUILD_STRATEGY=source             |
      | e        | ALLOW_ANON_GIT_PULL=false         |
    Then the step should succeed
    When a pod becomes ready with labels:
      | deploymentconfig=git |
      | deployment=git-2     |
    And I execute on the pod:
      | sh                                                                                                      |
      | -c                                                                                                      |
      | cd /var/lib/git/ && git clone --bare https://github.com/openshift/ruby-hello-world ruby-hello-world.git |
    Then the step should succeed
    When I run the :create_secret client command with:
      | name         | mysecret           |
      | secret_type  | generic            |
      | from_literal | username=openshift |
      | from_literal | password=redhat    |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | secret                                                                   |
      | resourcename | mysecret                                                                 |
      | keyval       | build.openshift.io/source-secret-match-uri-1=http://<%= cb.git_route%>/* |
    Then the step should succeed

    When I run the :new_app client command with:
      | app_repo | ruby~http://<%= cb.git_route %>/ruby-hello-world.git |
      | l        | app=newapp1                                          |
    Then the step should succeed
    When I get project buildconfig as YAML
    And the output should match:
      | sourceSecret   |
      | name: mysecret |
    Given the "ruby-hello-world-1" build completed
    When I run the :delete client command with:
      | all_no_dash |             |
      | l           | app=newapp1 |
    Then the step should succeed

    When I run the :new_build client command with:
      | app_repo | ruby~http://<%= cb.git_route %>/ruby-hello-world.git |
      | l        | app=newapp2                                          |
    Then the step should succeed
    When I get project buildconfig as YAML
    And the output should match:
      | sourceSecret   |
      | name: mysecret |
    Given the "ruby-hello-world-1" build completed
    When I run the :delete client command with:
      | all_no_dash |             |
      | l           | app=newapp2 |
    Then the step should succeed

    When I run the :create_secret client command with:
      | name         | override           |
      | secret_type  | generic            |
      | from_literal | username=openshift |
      | from_literal | password=redhat    |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | secret                                                                       |
      | resourcename | override                                                                     |
      | keyval       | build.openshift.io/source-secret-match-uri-1=http://<%= cb.git_route%>/ruby* |
    Then the step should succeed
    When I run the :new_app client command with:
      | app_repo | ruby~http://<%= cb.git_route %>/ruby-hello-world.git |
      | l        | app=newapp3                                          |
    Then the step should succeed
    #Multiple Secrets match the Git URI of a particular BuildConfig, the secret with the longest match will be took
    When I get project buildconfig as YAML
    And the output should match:
      | sourceSecret   |
      | name: override |
    And the output should not contain "mysecret"
    Given the "ruby-hello-world-1" build completed

    When I run the :delete client command with:
      | all_no_dash |             |
      | l           | app=newapp3 |
    Then the step should succeed
    When I run the :new_build client command with:
      | app_repo | ruby~http://<%= cb.git_route %>/ruby-hello-world.git |
    Then the step should succeed
    When I get project buildconfig as YAML
    And the output should match:
      | sourceSecret   |
      | name: override |
    And the output should not contain "mysecret"
    Given the "ruby-hello-world-1" build completed

