Feature: oc idle

  # @author chezhang@redhat.com
  # @case_id OCP-11633
  @4.21 @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-11633:Node CLI - Idle all the service in the same project
    Given I have a project
    Given I obtain test data file "rc/idle-rc-1.yaml"
    When I run the :create client command with:
      | f | idle-rc-1.yaml |
    Then the step should succeed
    Given I obtain test data file "rc/idle-rc-2.yaml"
    When I run the :create client command with:
      | f | idle-rc-2.yaml |
    Then the step should succeed
    Given I wait until replicationController "hello-pod" is ready
    And I wait until number of replicas match "2" for replicationController "hello-pod"
    Given 2 pods become ready with labels:
      | name=hello-pod  |
    Given I wait until replicationController "hello-idle" is ready
    And I wait until number of replicas match "2" for replicationController "hello-idle"
    Given 2 pods become ready with labels:
      | name=hello-idle |
    When I run the :idle client command with:
      | all | true      |
    Then the step should succeed
    And the output should match:
      | ReplicationController.*hello-idle |
      | ReplicationController.*hello-pod  |
    And the output should match 4 times:
      | (?i)idled |
    And I wait until number of replicas match "0" for replicationController "hello-pod"
    And I wait until number of replicas match "0" for replicationController "hello-idle"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | hello-idle.*none |
      | hello-svc.*none  |
    When I get project rc named "hello-pod" as YAML
    Then the output should match:
      | idling.*openshift.io/idled-at  |
    When I get project rc named "hello-idle" as YAML
    Then the output should match:
      | idling.*openshift.io/idled-at  |

  # @author chezhang@redhat.com
  # @case_id OCP-11980
  @4.21 @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-11980:Node CLI - Idle service by label
    Given I have a project
    Given I obtain test data file "rc/idle-rc-2.yaml"
    When I run the :create client command with:
      | f | idle-rc-2.yaml |
    Then the step should succeed
    Given I wait until replicationController "hello-pod" is ready
    And I wait until number of replicas match "2" for replicationController "hello-pod"
    Given 2 pods become ready with labels:
      | name=hello-pod |
    When I run the :label client command with:
      | resource | svc/hello-svc |
      | key_val  | idle=true     |
    Then the step should succeed
    When I run the :idle client command with:
      | l | idle=false |
    Then the step should succeed
    And I wait until number of replicas match "2" for replicationController "hello-pod"
    When I run the :idle client command with:
      | l | idle=true  |
    Then the step should succeed
    And the output should match:
      | ReplicationController.*hello-pod  |
      | (?i)idled |
    And I wait until number of replicas match "0" for replicationController "hello-pod"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | hello-svc.*none |
    When I get project rc named "hello-pod" as YAML
    Then the output should match:
      | idling.*openshift.io/idled-at |

  # @author chezhang@redhat.com
  # @case_id OCP-12085
  @4.21 @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-12085:Node CLI - Idle service from file
    Given I have a project
    Given I obtain test data file "rc/idle-rc-2.yaml"
    When I run the :create client command with:
      | f | idle-rc-2.yaml |
    Then the step should succeed
    Given I wait until replicationController "hello-pod" is ready
    And I wait until number of replicas match "2" for replicationController "hello-pod"
    Given 2 pods become ready with labels:
      | name=hello-pod |
    Given a "idle1.txt" file is created with the following lines:
    """
    hello-svc
    """
    Given a "idle2.txt" file is created with the following lines:
    """
    noexist-svc
    """
    When I run the :idle client command with:
      | resource-names-file | idle1.txt |
    Then the step should succeed
    And the output should match:
      | ReplicationController.*hello-pod |
      | (?i)idled |
    And I wait until number of replicas match "0" for replicationController "hello-pod"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | hello-svc.*none |
    When I get project rc named "hello-pod" as YAML
    Then the output should match:
      | idling.*openshift.io/idled-at   |
    When I run the :idle client command with:
      | resource-names-file | idle2.txt |
    Then the step should fail
    And the output should match:
      | no valid scalable resources found to idle: endpoints "noexist-svc" not found |

  # @author chezhang@redhat.com
  # @case_id OCP-12169
  @4.21 @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-12169:Node CLI - Idle service with dry-run
    Given I have a project
    Given I obtain test data file "rc/idle-rc-2.yaml"
    When I run the :create client command with:
      | f | idle-rc-2.yaml |
    Then the step should succeed
    Given I wait until replicationController "hello-pod" is ready
    And I wait until number of replicas match "2" for replicationController "hello-pod"
    Given 2 pods become ready with labels:
      | name=hello-pod |
    When I run the :idle client command with:
      | svc_name | hello-svc |
      | dry-run  | true      |
    Then the step should succeed
    And the output should match:
      | ReplicationController.*hello-pod |
      | (?i)idled |
    And I wait until number of replicas match "2" for replicationController "hello-pod"
    And 2 pods become ready with labels:
      | name=hello-pod  |
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should not match:
      | hello-svc.*none |
    When I get project rc named "hello-pod" as YAML
    Then the output should not match:
      | idling.*openshift.io/idled-at |

  # @author chezhang@redhat.com
  # @author minmli@redhat.com
  # @case_id OCP-10941
  @proxy @noproxy @disconnected @connected
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @critical
  Scenario: OCP-10941:Node Idling service with dc
    Given I have a project
    Given I obtain test data file "rc/idling-echo-server.yaml"
    When I run the :create client command with:
      | f | idling-echo-server.yaml |
    Then the step should succeed
    Given I wait until replicationController "idling-echo-1" is ready
    And I wait until number of replicas match "2" for replicationController "idling-echo-1"
    Given 2 pods become ready with labels:
      | app=idling-echo |
    When I run the :idle client command with:
      | svc_name | idling-echo |
    Then the step should succeed
    And the output should match:
      | DeploymentConfig.*idling-echo  |
      | (?i)idled |
    And I wait until number of replicas match "0" for replicationController "idling-echo-1"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | idling-echo.*none |
    When I get project dc named "idling-echo" as YAML
    Then the output should match:
      | idling.*openshift.io/idled-at |
    Given I use the "idling-echo" service
    And evaluation of `service.ip(user: user)` is stored in the :service_ip clipboard
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
    When I run the :exec client command with:
      | pod              | caddy-docker              |
      | exec_command     | curl                      |
      | exec_command_arg | <%= cb.service_ip %>:8675 |
      | _timeout         | 60                        |
    Then the output should match "GET.*HTTP"
    Given I wait until number of replicas match "2" for replicationController "idling-echo-1"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | idling-echo.*\d+.\d+.\d+.\d+:(3090\|8675),\d+.\d+.\d+.\d+:(3090\|8675),\d+.\d+.\d+.\d+:(8675\|3090) |
    Given 2 pods become ready with labels:
      | app=idling-echo |
    When I run the :idle client command with:
      | svc_name | idling-echo |
    Then the step should succeed
    And I wait until number of replicas match "0" for replicationController "idling-echo-1"
    And I run the :exec client command with:
      | pod              | caddy-docker                                  |
      | oc_opts_end      |                                               |
      | exec_command     | sh                                            |
      | exec_command_arg | -c                                            |
      | exec_command_arg | echo hello \| nc -u <%= cb.service_ip %> 3090 |
      | _timeout         | 60                                            |
    Given I wait until number of replicas match "2" for replicationController "idling-echo-1"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | idling-echo.*\d+.\d+.\d+.\d+:(3090\|8675),\d+.\d+.\d+.\d+:(3090\|8675),\d+.\d+.\d+.\d+:(8675\|3090) |

  # @author chezhang@redhat.com
  # @case_id OCP-11345
  @proxy @noproxy @disconnected @connected
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @critical
  Scenario: OCP-11345:Node Idling service with rc
    Given I have a project
    Given I obtain test data file "rc/idle-rc-2.yaml"
    When I run the :create client command with:
      | f | idle-rc-2.yaml |
    Then the step should succeed
    Given I wait until replicationController "hello-pod" is ready
    And I wait until number of replicas match "2" for replicationController "hello-pod"
    Given 2 pods become ready with labels:
      | name=hello-pod |
    When I run the :idle client command with:
      | svc_name | hello-svc |
    Then the step should succeed
    And the output should match:
      | ReplicationController.*hello-pod  |
      | (?i)idled |
    And I wait until number of replicas match "0" for replicationController "hello-pod"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | hello-svc.*none |
    When I get project rc named "hello-pod" as YAML
    Then the output should match:
      | idling.*openshift.io/idled-at |
    Given I use the "hello-svc" service
    And evaluation of `service.ip(user: user)` is stored in the :service_ip clipboard
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | --max-time | 60 | <%= cb.service_ip %>:8000 |
    Then the output should contain "Hello Pod!"
    """
    Given I ensure "caddy-docker" pod is deleted
    Given I wait until number of replicas match "2" for replicationController "hello-pod"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | hello-svc.*\d+.\d+.\d+.\d+:8080,\d+.\d+.\d+.\d+:8080 |

