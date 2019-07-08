Feature: AWS specific scenarios

  # @author chaoyang@redhat.com
  # @case_id OCP-14335
  @admin
  Scenario: Check two pods using one efs pv is working correctly
    Given I have a project
    And I have a efs-provisioner in the project
    When admin creates a StorageClass from "https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/aws/efs/deploy/class.yaml" where:
      | ["metadata"]["name"] | sc-<%= project.name %> |
      | ["provisioner"]      | openshift.org/aws-efs  |
    Then the step should succeed
    When I run oc create over "https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/aws/efs/deploy/claim.yaml" replacing paths:
      | ["metadata"]["name"]         | mypvc |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>     |
    Then the step should succeed
    And the "mypvc" PVC becomes :bound within 60 seconds
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/ebs/pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod1   |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
    Then the step should succeed
    And the pod named "mypod1" becomes ready
    When I execute on the pod:
      | touch | /tmp/file_pod1 |
    Then the step should succeed

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/ebs/pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod2   |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
    Then the step should succeed
    And the pod named "mypod2" becomes ready
    When I execute on the pod:
      | touch | /tmp/file_pod2 |
    Then the step should succeed
    When I execute on the pod:
      | ls | /tmp |
    Then the step should succeed
    Then the output should contain:
      | file_pod1 |
      | file_pod2 |

    And I ensure "mypvc" pvc is deleted
    And I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 300 seconds

