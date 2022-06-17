Feature: AWS specific scenarios

  # @author chaoyang@redhat.com
  # @case_id OCP-14335
  @admin
  Scenario: OCP-14335 Check two pods using one efs pv is working correctly
    Given I have a project
    And I have a efs-provisioner in the project
    When admin creates a StorageClass from "https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/aws/efs/deploy/class.yaml" where:
      | ["metadata"]["name"] | sc-<%= project.name %> |
      | ["provisioner"]      | openshift.org/aws-efs  |
    Then the step should succeed
    When I run oc create over "https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/aws/efs/deploy/claim.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | efspvc-<%= project.name %> |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | sc-<%= project.name %>     |
    Then the step should succeed
    And the "efspvc-<%= project.name %>" PVC becomes :bound within 60 seconds
    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/ebs/pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | pod1-<%= project.name %>   |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | efspvc-<%= project.name %> |
    Then the step should succeed
    And the pod named "pod1-<%= project.name %>" becomes ready
    When I execute on the pod:
      | touch | /tmp/file_pod1 |
    Then the step should succeed

    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/ebs/pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | pod2-<%= project.name %>   |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | efspvc-<%= project.name %> |
    Then the step should succeed
    And the pod named "pod2-<%= project.name %>" becomes ready
    When I execute on the pod:
      | touch | /tmp/file_pod2 |
    Then the step should succeed
    When I execute on the pod:
      | ls | /tmp |
    Then the step should succeed
    Then the output should contain:
      | file_pod1 |
      | file_pod2 |

    And I ensure "efspvc-<%= project.name %>" pvc is deleted
    And I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 300 seconds

