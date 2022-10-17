Feature: dockerbuild.feature

  # @author wzheng@redhat.com
  # @case_id OCP-12115
  @smoke
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-12115:BuildAPI Docker build with both SourceURI and context dir
    Given I have a project
    Given I obtain test data file "build/ruby20rhel7-context-docker.json"
    When I run the :create client command with:
      | f | ruby20rhel7-context-docker.json |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | ruby-helloworld-sample |
    Then the step should succeed
    And the "ruby20-sample-build-1" build was created
    And the "ruby20-sample-build-1" build completed
    When I run the :describe client command with:
      | resource | buildconfig         |
      | name     | ruby20-sample-build |
    Then the step should succeed
    And the output should contain "ContextDir:"

  # @author wzheng@redhat.com
  # @case_id OCP-30854
  @flaky
  @proxy
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-30854:BuildAPI Docker build with dockerImage with specified tag
    Given I have a project
    When I run the :new_app client command with:
      | docker_image | quay.io/openshifttest/ruby-27:1.2.0 |
      | app_repo     | http://github.com/openshift/ruby-hello-world  |
      | strategy     | docker                                        |
    Then the step should succeed
    And the "ruby-hello-world-1" build completes
    When I run the :patch client command with:
      | resource      | buildconfig                                                                                                                                      |
      | resource_name | ruby-hello-world                                                                                                                                 |
      | p             | {"spec": {"strategy": {"dockerStrategy": {"from": {"kind": "DockerImage","name": "registry.redhat.io/rhscl/ruby-27-rhel7:latest"}}},"type": "Docker"}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-2" build completes
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | buildconfig                                                                                                                                     |
      | resource_name | ruby-hello-world                                                                                                                                |
      | p             | {"spec": {"strategy": {"dockerStrategy": {"from": {"kind": "DockerImage","name": "quay.io/openshifttest/ruby-25-centos7:error"}}},"type": "Docker"}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | buildconfig      |
      | name     | ruby-hello-world |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-3" build failed
    When I run the :describe client command with:
      | resource | build              |
      | name     | ruby-hello-world-3 |
    Then the step should succeed
    And the output should contain "error"


  # @author dyan@redhat.com
  # @case_id OCP-13083
  @inactive
  Scenario: OCP-13083:BuildAPI Docker build using Dockerfile with 'FROM scratch'
    Given I have a project
    When I run the :new_build client command with:
      | D  | FROM scratch\nENV NUM 1 |
      | to | test                    |
    Then the step should succeed
    When the "test-1" build completed
    And I run the :logs client command with:
      | resource_name | bc/test |
      | f             |         |
    Then the output should contain:
      | FROM scratch |
    And the output should not match:
      | [Ee]rror |

  # @author dyan@redhat.com
  # @case_id OCP-12855
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-12855:BuildAPI Add ARGs in docker build
    Given I have a project
    When I run the :new_build client command with:
      | code         | http://github.com/openshift/ruby-hello-world.git |
      | docker_image | quay.io/openshifttest/ruby-27:1.2.0          |
      | strategy     | docker                                           |
      | build_arg    | ARG=VALUE                                        |
    Then the step should succeed
    Given the "ruby-hello-world-1" build was created
    When I run the :get client command with:
      | resource | build/ruby-hello-world-1 |
      | o        | yaml                     |
    Then the step should succeed
    And the output should match:
      | name:\\s+ARG    |
      | value:\\s+VALUE |
    # start build with build-arg
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
      | build_arg   | ARG1=VALUE1      |
    Then the step should succeed
    Given the "ruby-hello-world-2" build was created
    When I run the :get client command with:
      | resource | build/ruby-hello-world-2 |
      | o        | yaml                     |
    Then the step should succeed
    And the output should match:
      | name:\\s+ARG1    |
      | value:\\s+VALUE1 |
    When I run the :start_build client command with:
      | from_build | ruby-hello-world-1 |
      | build_arg  | ARG=NEWVALUE       |
    Then the step should succeed
    Given the "ruby-hello-world-3" build was created
    When I run the :get client command with:
      | resource | build/ruby-hello-world-3 |
      | o        | yaml                     |
    Then the step should succeed
    And the output should match:
      | name:\\s+ARG       |
      | value:\\s+NEWVALUE |

  # @author wzheng@redhat.com
  # @case_id OCP-18501
  @inactive
  Scenario: OCP-18501:ImageRegistry Support additional EXPOSE values in new-app
    Given I have a project
    When I run the :new_app client command with:
      | code | https://github.com/openshift-qe/oc_newapp_expose |
    Then the step should succeed
    And the output should contain:
      | invalid ports in EXPOSE instruction |
      | Ports 8080/tcp, 8081/tcp, 8083/tcp, 8084/tcp, 8085/tcp, 8087/tcp, 8090/tcp, 8091/tcp, 8092/tcp, 8093/tcp, 8094/tcp, 8100/udp, 8101/udp |

  # @author xiuwang@redhat.com
  # @case_id OCP-42157
  @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-42157:BuildAPI Mount source secret to builder container- dockerstrategy
    Given I have a project
    When I run the :create_secret client command with:
      | secret_type  | generic            |
      | name         | mysecret           |
      | from_literal | username=openshift |
      | from_literal | password=redhat    |
    Then the step should succeed
    When I run the :new_build client command with:
      | D | FROM quay.io/openshifttest/base-alpine:1.2.0\nRUN ls -l /var/run/secret/sourcesecret |
    Then the step should succeed
    Then the "base-alpine" image stream was created
    And the "base-alpine-1" build was created
    Given the "base-alpine-1" build failed
    When I run the :patch client command with:
      | resource      | buildconfig |
      | resource_name | base-alpine |
      | p             | {"spec":{"strategy":{"dockerStrategy":{"volumes":[{"mounts":[{"destinationPath":"/var/run/secret/sourcesecret"}],"name":"some-secret","source":{"secret":{"secretName":"mysecret"},"type":"Secret"}}]}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | base-alpine |
    Then the step should succeed
    Given the "base-alpine-2" build was created
    Given the "base-alpine-2" build completed
    And I run the :logs client command with:
      | resource_name | bc/base-alpine |
      | f             |           |
    Then the output should contain:
      | RUN ls -l /var/run/secret/sourcesecret |
      | password -> ..data/password            |
      | username -> ..data/username            |

  # @author xiuwang@redhat.com
  # @case_id OCP-42158
  @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-42158:BuildAPI Mount source configmap to builder container- dockerstrategy
    Given I have a project
    When I run the :create_configmap client command with:
      | name         | myconfig  |
      | from_literal | key=foo   |
      | from_literal | value=bar |
    Then the step should succeed
    When I run the :new_build client command with:
      | D | FROM quay.io/openshifttest/base-alpine:1.2.0\nRUN ls -l /var/run/secret/config |
    Then the step should succeed
    Then the "base-alpine" image stream was created
    And the "base-alpine-1" build was created
    Given the "base-alpine-1" build failed
    When I run the :patch client command with:
      | resource      | buildconfig |
      | resource_name | base-alpine |
      | p             | {"spec":{"strategy":{"dockerStrategy":{"volumes":[{"mounts":[{"destinationPath":"/var/run/secret/config"}],"name":"my-config","source":{"configMap":{"name":"myconfig"},"type":"ConfigMap"}}]}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | base-alpine |
    Then the step should succeed
    Given the "base-alpine-2" build was created
    Given the "base-alpine-2" build completed
    And I run the :logs client command with:
      | resource_name | bc/base-alpine |
      | f             |                |
    Then the output should contain:
      | RUN ls -l /var/run/secret/config |
      | key -> ..data/key                |
      | value -> ..data/value            |

  # @author xiuwang@redhat.com
  # @case_id OCP-42184
  @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-42184:BuildAPI Mount multi paths to builder container
    Given I have a project
    When I run the :create_secret client command with:
      | secret_type  | generic            |
      | name         | mysecret           |
      | from_literal | username=openshift |
      | from_literal | password=redhat    |
    Then the step should succeed
    When I run the :new_build client command with:
      | D | FROM quay.io/openshifttest/base-alpine:1.2.0\nRUN ls -l /var/run/secret/secret-1\nRUN ls -l /var/run/secret/secret-2 |
    Then the step should succeed
    Then the "base-alpine" image stream was created
    And the "base-alpine-1" build was created
    Given the "base-alpine-1" build failed
    When I run the :patch client command with:
      | resource      | buildconfig |
      | resource_name | base-alpine |
      | p             | {"spec":{"strategy":{"dockerStrategy":{"volumes":[{"mounts":[{"destinationPath":"/var/run/secret/secret-1"},{"destinationPath":"/var/run/secret/secret-2"}],"name":"mysecret","source":{"secret":{"secretName":"mysecret"},"type":"Secret"}}]}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | base-alpine |
    Then the step should succeed
    Given the "base-alpine-2" build was created
    Given the "base-alpine-2" build completed
    And I run the :logs client command with:
      | resource_name | bc/base-alpine |
      | f             |                |
    Then the output should contain:
      | RUN ls -l /var/run/secret/secret-1 |
      | RUN ls -l /var/run/secret/secret-2 |
      | password -> ..data/password        |
      | username -> ..data/username        |

  # @author xiuwang@redhat.com
  # @case_id OCP-42185
  @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-42185:BuildAPI Can't add relative path for mount path
    Given I have a project
    When I run the :create_secret client command with:
      | secret_type  | generic            |
      | name         | mysecret           |
      | from_literal | username=openshift |
      | from_literal | password=redhat    |
    Then the step should succeed
    When I run the :new_build client command with:
      | D | FROM quay.io/openshifttest/base-alpine:1.2.0\nRUN ls -l /var/run/secret/secret-1|
    Then the step should succeed
    Then the "base-alpine" image stream was created
    And the "base-alpine-1" build was created
    When I run the :patch client command with:
      | resource      | buildconfig |
      | resource_name | base-alpine |
      | p             | {"spec":{"strategy":{"dockerStrategy":{"volumes":[{"mounts":[{"destinationPath":"../secret/secret-1"}],"name":"mysecret","source":{"secret":{"secretName":"mysecret"},"type":"Secret"}}]}}}} |
    Then the step should fail
    Then the output should contain:
      | must be an absolute path |
      | must not start with '..' |
    When I run the :patch client command with:
      | resource      | buildconfig |
      | resource_name | base-alpine |
      | p             | {"spec":{"strategy":{"dockerStrategy":{"volumes":[{"mounts":[{"destinationPath":"secret/secret-1"}],"name":"mysecret","source":{"secret":{"secretName":"mysecret"},"type":"Secret"}}]}}}} |
    Then the step should fail
    Then the output should contain:
      | Invalid value: "secret/secret-1": must be an absolute path |

  # @author xiuwang@redhat.com
  # @case_id OCP-42529
  @4.12 @4.11 @4.10 @4.9
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-42529:BuildAPI Mount source name must be unique
    Given I have a project
    When I run the :create_secret client command with:
      | secret_type  | generic            |
      | name         | testsource         |
      | from_literal | username=openshift |
      | from_literal | password=redhat    |
    Then the step should succeed
    When I run the :create_configmap client command with:
      | name         | testsource |
      | from_literal | key=foo    |
      | from_literal | value=bar  |
    Then the step should succeed
    When I run the :new_build client command with:
      | D | FROM quay.io/openshifttest/base-alpine:1.2.0\nRUN ls -l /var/run/secret |
    Then the step should succeed
    Then the "base-alpine" image stream was created
    And the "base-alpine-1" build was created
    When I run the :patch client command with:
      | resource      | buildconfig |
      | resource_name | base-alpine      |
      | p             | {"spec":{"strategy":{"dockerStrategy":{"volumes":[{"mounts":[{"destinationPath":"/var/run/secret/mysecret"}],"name":"mysecret","source":{"secret":{"secretName":"testsource"},"type":"Secret"}},{"mounts":[{"destinationPath":"/var/run/secret/myconfig"}],"name":"myconfig","source":{"configMap":{"name":"testsource"},"type":"ConfigMap"}}]}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | base-alpine |
    Then the step should succeed
    Given the "base-alpine-2" build was created
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | build         |
      | name     | base-alpine-2 |
    Then the step should succeed
    Then the output should contain:
      | spec.containers[0].volumeMounts[11].mountPath: Invalid value: "/var/run/openshift.io/volumes/testsource-user-build-volume": must be unique |
    """
