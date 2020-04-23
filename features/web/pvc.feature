Feature: Add pvc to pod from web related

  # @author yanpzhan@redhat.com
  # @case_id OCP-10752
  @admin
  @destructive
  Scenario: Attach pvc to pod with multiple containers from web console
    Given I have a project
    And I have a NFS service in the project
    And default storage class is patched to non-default
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/deployment/dc-with-two-containers.yaml |
    Then the step should succeed

    When admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/auto/pv-template.json" where:
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]       | nfs-1-<%= project.name %>         |
    Then the step should succeed

    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | nfsc-1-<%= project.name %> |
      | ["spec"]["volumeName"] | nfs-1-<%= project.name %>  |
    Then the step should succeed
    And the "nfsc-1-<%= project.name %>" PVC becomes bound to the "nfs-1-<%= project.name %>" PV

    When admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/auto/pv-template.json" where:
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]       | nfs-2-<%= project.name %>         |
    Then the step should succeed

    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | nfsc-2-<%= project.name %> |
      | ["spec"]["volumeName"] | nfs-2-<%= project.name %>  |
    Then the step should succeed
    And the "nfsc-2-<%= project.name %>" PVC becomes bound to the "nfs-2-<%= project.name %>" PV

    Given I wait until the status of deployment "dctest" becomes :complete

    #Add pvc to one of the containers
    When I perform the :add_pvc_to_one_container web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | dctest              |
      | mount_path   | /mnt                |
      | volume_name  | v1                |
    Then the step should succeed
    And I wait until the status of deployment "dctest" becomes :complete

    Given 1 pods become ready with labels:
      | run=dctest |

    When I run the :exec client command with:
      | pod | <%= pod.name %>          |
      | c   | dctest-1                 |
      | exec_command | grep            |
      | exec_command_arg | mnt         |
      | exec_command_arg | /proc/mounts|
    Then the step should succeed

    #Add pvc to all containers by default
    When I perform the :add_pvc_to_all_default_containers web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | dctest              |
      | mount_path   | /tmp                |
      | volume_name  | v2                |
    Then the step should succeed
    And I wait until the status of deployment "dctest" becomes :complete

    Given 1 pods become ready with labels:
      | run=dctest |

    When I run the :exec client command with:
      | pod | <%= pod.name %>    |
      | c   | dctest-1           |
      | exec_command | touch     |
      | exec_command_arg |/tmp/f1|
    Then the step should succeed

    When I run the :exec client command with:
      | pod | <%= pod.name %>    |
      | c   | dctest-2           |
      | exec_command | ls        |
      | exec_command_arg |/tmp   |
    Then the step should succeed
    And the output should contain:
      | f1 |
