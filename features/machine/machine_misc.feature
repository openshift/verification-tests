Feature: Machine misc features testing

  # @author miyadav@redhat.com
  # @case_id OCP-34940
  @admin
  @destructive
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

