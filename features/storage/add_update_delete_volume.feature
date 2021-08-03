Feature: Add, update remove volume to rc/dc and --overwrite option

  # @author chaoyang@redhat.com
  # @case_id OCP-10284
  @smoke
  Scenario: Check add or remove volume from dc works fine
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/mongodb:latest   |
      | env          | MONGODB_USER=tester        |
      | env          | MONGODB_PASSWORD=xxx       |
      | env          | MONGODB_DATABASE=testdb    |
      | env          | MONGODB_ADMIN_PASSWORD=yyy |
      | name         | mydb                       |
    Then the step should succeed
    And a pod becomes ready with labels:
      | deployment=mydb |
    # Check oc volume command
    When I run the :set_volume client command with:
      | resource   | deployment/mydb |
      | action     | --add           |
      | type       | emptyDir        |
      | mount-path | /opt1           |
      | name       | v1              |
    Then the step should succeed
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear
    And a pod becomes ready with labels:
      | deployment=mydb |
    When I execute on the pod:
      | grep | opt1 | /proc/mounts |
    Then the step should succeed
    # remove pvc from dc
    When I run the :set_volume client command with:
      | resource | deployment/mydb  |
      | action   | --remove         |
      | name     | v1               |
    Then the step should succeed
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear
    And a pod becomes ready with labels:
      | deployment=mydb |
    When I get project deployment named "mydb" as YAML
    Then the step should succeed
    And the output should not contain:
      | name: v1 |
    # Check set volume command
    When I run the :set_volume client command with:
      | resource      | deployment |
      | resource_name | mydb       |
      | action        | --add      |
      | name          | v1         |
      | type          | emptyDir   |
      | mount-path    | /opt1      |
    Then the step should succeed
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear
    And a pod becomes ready with labels:
      | deployment=mydb |
    When I execute on the pod:
      | grep | opt1 | /proc/mounts |
    Then the step should succeed
    Then I run the :set_volume client command with:
      | resource      | deployment |
      | resource_name | mydb       |
      | action        | --add      |
      | name          | v1         |
      | type          | emptyDir   |
      | mount-path    | /opt2      |
      | overwrite     |            |
    Then the step should succeed
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear
    And a pod becomes ready with labels:
      | deployment=mydb |
    When I execute on the pod:
      | grep | opt2 | /proc/mounts |
    Then the step should succeed
    When I run the :set_volume client command with:
      | resource | deployment/mydb |
      | action   | --remove        |
      | name     | v1              |
    Then the step should succeed
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear
    And a pod becomes ready with labels:
      | deployment=mydb |
    When I get project deployment named "mydb" as YAML
    Then the step should succeed
    And the output should not contain:
      | name: v1 |

