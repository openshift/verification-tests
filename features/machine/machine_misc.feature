Feature: Machine misc features testing

  # @author miyadav@redhat.com
  # @case_id OCP-34940
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: PVCs can still be provisioned after the password has been changed vSphere
    Given I have an IPI deployment
    Then I switch to cluster admin pseudo user

    When I run the :get admin command with:
      | resource      | secret        |
      | resource_name | vsphere-creds |
      | n             | kube-system   |
      | o             | yaml          |
   And I save the output to file> vsphere-creds_original.yaml
   Then the "vsphere-creds" secret is recreated by admin in the "kube-system" project after scenario

   Given I obtain test data file "cloud/misc/vsphere-creds_test.yaml"
   Then I run the :replace admin command with:
      | _tool | oc                       |
      | f     | vsphere-creds_test.yaml  |
   Then the step should succeed

   Given I use the "openshift-config" project
   When as admin I successfully merge patch resource "cm/cloud-provider-config" with:
     |  {"data": {"immutable": "false"}} |

   Then I use the "openshift-machine-api" project
   When 240 seconds have passed

   Then I obtain test data file "cloud/misc/PVC.yaml"
   And I run oc create over "PVC.yaml" replacing paths:
     | n | openshift-machine-api |
   Then the step should succeed
   And admin ensures "pvc" pvc is deleted after scenario

   Given I obtain test data file "cloud/misc/nginx-pod.yaml"
   When I run oc create over "nginx-pod.yaml" replacing paths:
     | n | openshift-machine-api |
   And admin ensures "mypod" pod is deleted after scenario

   Then I get project events
   And the output should match:
     | Failed to provision volume with StorageClass "thin": ServerFaultCode: Cannot complete login |

   Then I run the :replace admin command with:
      | _tool | oc                           |
      | f     | vsphere-creds_original.yaml  |
      | force |                              |
   And the step should succeed

   Then I get project events
   And the output should match:
     | Successfully provisioned volume |

  # @author miyadav@redhat.com
  # @case_id OCP-35454
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Reconciliation of MutatingWebhookConfiguration values should happen
    Given I switch to cluster admin pseudo user

    Given I use the "openshift-cluster-version" project
    Then I run the :scale admin command with:
      | resource | deployment               |
      | name     | cluster-version-operator |
      | replicas | 0                        |
    And the step should succeed
    And admin ensures the deployment replicas is restored to "1" in "openshift-cluster-version" for "cluster-version-operator" after scenario

    Given I use the "openshift-machine-api" project
    Then I run the :scale admin command with:
      | resource | deployment           |
      | name     | machine-api-operator |
      | replicas | 0                    |
    And the step should succeed
    And admin ensures the deployment replicas is restored to "1" in "openshift-machine-api" for "machine-api-operator" after scenario

    When I run the :patch admin command with:
      | resource      | MutatingWebhookConfiguration                                                      |
      | resource_name | machine-api                                                                       |
      | p             | [{"op": "replace", "path": "/webhooks/0/clientConfig/service/port", "value":444}] |
      | type          | json                                                                              |
    And the step should succeed

    Given I use the "openshift-cluster-version" project
    Then I run the :scale admin command with:
      | resource | deployment               |
      | name     | cluster-version-operator |
      | replicas | 1                        |
    And the step should succeed

    Given I use the "openshift-machine-api" project
    Then I run the :scale admin command with:
      | resource | deployment           |
      | name     | machine-api-operator |
      | replicas | 1                    |
    And the step should succeed

    Given I wait up to 180 seconds for the steps to pass:
    """
    And I run the :get admin command with:
      | resource      | MutatingWebhookConfiguration |
      | resource_name | machine-api                  |
      | o             | json                         |
    Then the expression should be true>  @result[:parsed]['webhooks'][0]['clientConfig']['service']['port'] == 443
    """

  # @author miyadav@redhat.com
  # @case_id OCP-37744
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: kube-rbac-proxy should not expose tokens, have excessive verbosity
    Given I switch to cluster admin pseudo user

    Given I use the "openshift-machine-api" project
    Given a pod becomes ready with labels:
      | api=clusterapi | k8s-app=controller |
    Given evaluation of `["kube-rbac-proxy-machine-mtrc", "kube-rbac-proxy-machineset-mtrc", "kube-rbac-proxy-mhc-mtrc"]` is stored in the :containers clipboard
    And I repeat the following steps for each :container in cb.containers:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %> |
      | c             | #{cb.container} |
    Then the output should not contain:
      | Response Headers |
    """

    Given I use the "openshift-machine-api" project
    Given evaluation of `["machine-api-operator", "cluster-autoscaler-operator"]` is stored in the :labels clipboard
    And I repeat the following steps for each :label in cb.labels:
    """
    Given a pod becomes ready with labels:
      | api=clusterapi | k8s-app=#{cb.label} |
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %> |
      | c             | kube-rbac-proxy |
    Then the output should not contain:
      | Response Headers |
    """

    Given I use the "openshift-cluster-machine-approver" project
    Given a pod becomes ready with labels:
      | api=clusterapi | app=machine-approver |
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %> |
      | c             | kube-rbac-proxy |
    Then the output should not contain:
      | Response Headers |

  # @author miyadav@redhat.com
  # @case_id OCP-37180
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Report vCenter version to telemetry
    Given I switch to cluster admin pseudo user
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                         |
      | query | cloudprovider_vsphere_vcenter_versions |
    Then the step should succeed
    And the expression should be true> @result[:parsed]["data"]["result"][0]["metric"]["version"] =~ /7.0/

  # @author miyadav@redhat.com
  # @case_id OCP-40665
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8
  @vsphere-ipi
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Deattach disk before destroying vm from vsphere
    Given I switch to cluster admin pseudo user
    Then I use the "openshift-machine-api" project
    And I clone a machineset and name it "machineset-clone-40665"

    Given I store the last provisioned machine in the :new_machine clipboard
    And evaluation of `machine(cb.new_machine).node_name` is stored in the :nodeRef clipboard

    When I run the :label admin command with:
      | resource | node                |
      | name     | <%= cb.nodeRef %>   |
      | key_val  | testcase=ocp40665   |
    Then the step should succeed

    Given I obtain test data file "cloud/misc/pvc-40665.yaml"
    When I run the :create admin command with:
      | f | pvc-40665.yaml |
    Then the step should succeed
    And admin ensures "pvc-cloud" pvc is deleted after scenario

    Given I obtain test data file "cloud/misc/deployment-40665.yaml"
    When I run the :create admin command with:
      | f | deployment-40665.yaml |
    Then the step should succeed
    And admin ensures "dep-40665" deployment is deleted after scenario

    Given I obtain test data file "cloud/mhc/kubelet-killer-pod.yml"
    When I run oc create over "kubelet-killer-pod.yml" replacing paths:
	    | ["spec"]["nodeName"]  | "<%= machine(cb.new_machine).node_name %>" |
    Then the step should succeed

    When I run the :delete admin command with:
      | object_type       | machine                |
      | object_name_or_id | <%= cb.new_machine %>  |
    Then the step succeeded

    Given a pod becomes ready with labels:
      | api=clusterapi, k8s-app=controller |
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>    |
      | c             | machine-controller |
    Then the output should contain:
      | Detaching disks before vm destroy  |


