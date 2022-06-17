Feature: Add pvc to pod from web related

  # @author yanpzhan@redhat.com
  # @case_id OCP-10752
  @admin
  @destructive
  Scenario: OCP-10752 Attach pvc to pod with multiple containers from web console
    Given I have a project
    And I have a NFS service in the project
    And default storage class is deleted
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/dc-with-two-containers.yaml |
    Then the step should succeed

    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pv-template.json" where:
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]       | nfs-1-<%= project.name %>         |
    Then the step should succeed

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | nfsc-1-<%= project.name %> |
      | ["spec"]["volumeName"] | nfs-1-<%= project.name %>  |
    Then the step should succeed
    And the "nfsc-1-<%= project.name %>" PVC becomes bound to the "nfs-1-<%= project.name %>" PV

    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pv-template.json" where:
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]       | nfs-2-<%= project.name %>         |
    Then the step should succeed

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pvc-template.json" replacing paths:
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

  # @author yanpzhan@redhat.com
  # @case_id OCP-10126
  Scenario: OCP-10126 Create persist volume claim from web console
    Given I have a project

    # Create ROX type pvc
    When I perform the :create_pvc_from_storage_page web console action with:
      | project_name    | <%= project.name %> |
      | pvc_name        | wehe-100            |
      | pvc_access_mode | ReadOnlyMany        |
      | storage_size    | 0.01                |
      | storage_unit    | TiB                 |
    Then the step should succeed

    When I perform the :check_pvc_info web console action with:
      | project_name    | <%= project.name %>  |
      | pvc_name        | wehe-100             |
      | pvc_access_mode | ROX (Read-Only-Many) |
      | storage_size    | 10995116277760 mB    |
    Then the step should succeed

    # Create pvc with existing pvc name
    When I perform the :create_pvc_from_storage_page web console action with:
      | project_name    | <%= project.name %> |
      | pvc_name        | wehe-100            |
      | pvc_access_mode | ReadOnlyMany        |
      | storage_size    | 0.01                |
      | storage_unit    | TiB                 |
    Then the step should fail
    When I perform the :check_prompt_info_for_pvc web console action with:
      | prompt_info | "wehe-100" already exists |
    Then the step should succeed

    When I run the :cancel_pvc_creation web console action
    Then the step should succeed

    # Delete pvc from web console
    When I perform the :delete_resources_pvc web console action with:
      | project_name    | <%= project.name %> |
      | pvc_name        | wehe-100            |
    Then the step should succeed
    When I perform the :check_prompt_info_for_pvc web console action with:
      | prompt_info | marked for deletion |
    Then the step should succeed

    # Create RWX type pvc
    When I perform the :create_pvc_from_storage_page web console action with:
      | project_name    | <%= project.name %> |
      | pvc_name        | 0123456789          |
      | pvc_access_mode | ReadWriteMany       |
      | storage_size    | 1024                |
      | storage_unit    | MiB                 |
    Then the step should succeed

    When I perform the :check_pvc_info web console action with:
      | project_name    | <%= project.name %>   |
      | pvc_name        | 0123456789            |
      | pvc_access_mode | RWX (Read-Write-Many) |
      | storage_size    | 1 GiB                 |
    Then the step should succeed

    # Delete pvc from web console
    When I perform the :delete_resources_pvc web console action with:
      | project_name    | <%= project.name %> |
      | pvc_name        | 0123456789          |
    Then the step should succeed
    When I perform the :check_prompt_info_for_pvc web console action with:
      | prompt_info | marked for deletion |
    Then the step should succeed

    # Create RWO type pvc
    When I perform the :create_pvc_from_storage_page web console action with:
      | project_name    | <%= project.name %> |
      | pvc_name        | wehepvc             |
      | pvc_access_mode | ReadWriteOnce       |
      | storage_size    | 1025                |
      | storage_unit    | MiB                 |
    Then the step should succeed

    When I perform the :check_pvc_info web console action with:
      | project_name    | <%= project.name %>   |
      | pvc_name        | wehepvc               |
      | pvc_access_mode | RWO (Read-Write-Once) |
      | storage_size    | 1025 MiB              |
    Then the step should succeed

    # Check invalid pvc name with special symbol
    When I perform the :create_pvc_with_invalid_name_and_check web console action with:
      | project_name    | <%= project.name %> |
      | pvc_name        | $%$#                |
      | storage_size    | 100                 |
    Then the step should succeed

    # Check invalid pvc name with '-' at the beginning
    When I perform the :create_pvc_with_invalid_name_and_check web console action with:
      | project_name    | <%= project.name %> |
      | pvc_name        | -test               |
      | storage_size    | 100                 |
    Then the step should succeed

    # Check invalid pvc name with '-' at the end
    When I perform the :create_pvc_with_invalid_name_and_check web console action with:
      | project_name    | <%= project.name %> |
      | pvc_name        | test-               |
      | storage_size    | 100                 |
    Then the step should succeed

    # Check invalid pvc name with more than 253 characters
    When I perform the :create_pvc_with_invalid_value_and_check web console action with:
      | project_name    | <%= project.name %>        |
      | pvc_name        | <%= rand_str(254, :dns) %> |
      | storage_size    | 100                        |
    Then the step should succeed

    # Check invalid pvc name one character(min length)
    When I perform the :create_pvc_with_min_length_and_check web console action with:
      | project_name    | <%= project.name %>      |
      | pvc_name        | <%= rand_str(1, :dns) %> |
      | storage_size    | 100                      |
    Then the step should succeed

    # Check invalid pvc size
    When I perform the :create_pvc_with_invalid_value_and_check web console action with:
      | project_name    | <%= project.name %> |
      | pvc_name        | pvctest             |
      | storage_size    | $$$####%            |
    Then the step should succeed

