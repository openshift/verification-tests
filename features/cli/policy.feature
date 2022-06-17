Feature: change the policy of user/service account

  # @author xxing@redhat.com
  # @case_id OCP-11074
  Scenario: OCP-11074 User can view ,add, remove and modify roleBinding via admin role user
    Given I have a project
    When I run the :get client command with:
      | resource      | rolebinding |
      | resource_name | admin       |
      | o             | wide        |
    Then the output should match:
      | admin.*<%= @user.name %> |
    When I run the :oadm_add_role_to_user client command with:
      | role_name        | admin                              |
      | user_name        | <%= user(1, switch: false).name %> |
      | rolebinding_name | admin                              |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | rolebinding |
      | resource_name | admin       |
      | o             | wide        |
    Then the output should match:
      | admin.*<%= @user.name %>, <%= user(1, switch: false).name %> |
    Given I switch to the second user
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource | projects |
    Then the output should contain "<%= project.name %>"
    """
    Given I switch to the first user
    When I run the :oadm_remove_role_from_user client command with:
      | role_name | admin            |
      | user_name | <%= user(1, switch: false).name %> |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | rolebinding |
      | resource_name | admin       |
      | o             | wide        |
    Then the output should match:
      | admin.*<%= @user.name %> |
    Given I switch to the second user
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource | projects |
    Then the output should not contain "<%= project.name %>"
    """

  # @author xxing@redhat.com
  # @case_id OCP-12430
  @admin
  Scenario: OCP-12430 Could get projects for new role which has permission to get projects
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/clustergetproject.json |
    Then the step should succeed
    #clean-up clusterrole
    And I register clean-up steps:
      | I run the :delete admin command with: |
      |   ! f ! https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/clustergetproject.json ! |
      | the step should succeed               |
    When admin creates a project
    Then the step should succeed
    When I run the :oadm_add_role_to_user admin command with:
      | role_name      | viewproject      |
      | user_name      | <%= user.name %> |
      | n              | <%= project.name %> |
    Then the step should succeed
    When I run the :get client command with:
      | resource | project |
    Then the output should match:
      | <%= project.name %>.*Active |

  # @author xiaocwan@redhat.com
  # @case_id OCP-11442
  Scenario: [origin_platformexp_214] User can view, add , modify and delete specific role to/from new added project via admin role user
    Given I have a project
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/projectviewservice.json"
    When I run the :create client command with:
      | f            | projectviewservice.json     |
    Then the step should succeed
    And the output should contain:
      | created      |
    When I run the :describe client command with:
      | namespace    | <%= project.name %> |
      | resource     | role                |
      | name         | viewservices        |
    Then the step should succeed
    And the output should contain:
      | get                                |
      | list                               |
      | watch                              |

    When I delete matching lines from "projectviewservice.json":
      | "get",       |
    Then the step should succeed
    When I run the :replace client command with:
      | f            | projectviewservice.json      |
    Then the step should succeed
    And the output should contain:
      | replaced     |
    When I run the :describe client command with:
      | namespace    | <%= project.name %> |
      | resource     | role                |
      | name         | viewservices        |
    Then the step should succeed
    And the output should not contain:
      | get          |

    When I run the :delete client command with:
      | object_type       | role                    |
      | object_name_or_id | viewservices            |
    Then the step should succeed
    And the output should contain:
      | deleted          |
    When I run the :describe client command with:
      | namespace    | <%= project.name %>          |
      | resource     | role                       |
      | name         | viewservices                      |
    Then the step should fail
    And the output should not contain:
      | list          |
      | watch         |

  # @author wsun@redhat.com
  # @case_id OCP-11273
  @admin
  Scenario: OCP-11273 UserA could impersonate UserB
    Given I have a project
    Given cluster role "sudoer" is added to the "first" user
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/daemon/daemonset.yaml |
    Then the step should fail
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/daemon/daemonset.yaml |
      | as | system:admin    |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/daemon/daemonset.yaml |
      | as | <%= user(1, switch: false).name %>    |
    Then the step should fail

  # @author chezhang@redhat.com
  # @case_id OCP-10211
  @admin
  Scenario: OCP-10211 DaemonSet only support Always restartPolicy
    Given I have a project
    Given cluster role "sudoer" is added to the "first" user
    When I run the :create client command with:
      | f  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/daemon/daemonset-negtive-onfailure.yaml |
      | as | system:admin |
    Then the step should fail
    And the output should match:
      | Unsupported value: "OnFailure": supported values: "?Always"? |
    When I run the :create client command with:
      | f  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/daemon/daemonset-negtive-never.yaml |
      | as | system:admin |
    Then the step should fail
    And the output should match:
      | Unsupported value: "Never": supported values: "?Always"? |
    When I run the :create client command with:
      | f  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/daemon/daemonset.yaml |
      | as | system:admin |
    Then the step should succeed

  # @author chaoyang@redhat.com
  # @case_id OCP-10447
  Scenario: OCP-10447 Basic user could not get deeper storageclass object info
    Given I have a project
    When I run the :get client command with:
      | resource | storageclass |
      | o        | yaml         |
    Then the step should succeed
    And I save the output to file> sc_names.yaml

    When I run the :get client command with:
      | resource      | :false        |
      | resource_name | :false        |
      | f             | sc_names.yaml |
      | o             | yaml          |
    Then the step should succeed

    When I run the :get client command with:
      | resource | storageclass |
      | o        | yaml         |
    Then the step should succeed

    When I run the :describe client command with:
      | resource | :false        |
      | name     | :false        |
      | f        | sc_names.yaml |
    Then the step should succeed

    When I run the :delete client command with:
      | object_type       | :false        |
      | object_name_or_id | :false        |
      | f                 | sc_names.yaml |
    And the output should match:
      | Error.*storageclasses.* at the cluster scope |

    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/ebs/dynamic-provisioning/storageclass-io1.yaml |
    Then the step should fail
    And the output should match:
      | Error.*storageclasses.* at the cluster scope |


  # @author chaoyang@redhat.com
  # @case_id OCP-10448
  @admin
  Scenario: OCP-10448 User with role storage-admin can check deeper storageclass object info
    Given I have a project
    And admin ensures "sc-<%= project.name %>" storageclasses is deleted after scenario
    Given cluster role "storage-admin" is added to the "first" user

    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/ebs/dynamic-provisioning/storageclass-io1.yaml"
    Then I replace lines in "storageclass-io1.yaml":
      | foo | sc-<%= project.name %> |
    Then I run the :create client command with:
      | f | storageclass-io1.yaml |
    Then the step should succeed

    When I run the :get client command with:
      | resource | storageclass |
    Then the step should succeed
    And the output should contain:
      | sc-<%= project.name %> |

    When I run the :get client command with:
      | resource      | storageclass           |
      | resource_name | sc-<%= project.name %> |
      | o             | yaml                   |
    Then the step should succeed

    When I run the :describe client command with:
      | resource | storageclass           |
      | name     | sc-<%= project.name %> |
    Then the step should succeed

    # Update storageclass
    Then I replace lines in "storageclass-io1.yaml":
      | 25 | 30 |

    Then I run the :replace client command with:
      | f     | storageclass-io1.yaml |
      | force | true                  |
    And the step should succeed

    When I run the :describe client command with:
      | resource | storageclass           |
      | name     | sc-<%= project.name %> |
    Then the step should succeed
    And the output should contain:
      | iopsPerGB=30 |

    # Delete storageclass
    When I run the :delete client command with:
      | object_type       | storageclass           |
      | object_name_or_id | sc-<%= project.name %> |
    Then the step should succeed
    Then I wait for the resource "storageclass" named "sc-<%= project.name %>" to disappear within 60 seconds

  # @author chaoyang@redhat.com
  # @case_id OCP-10466
  @admin
  Scenario: OCP-10466 User with role storage-admin can check deeper pv object info
    Given I have a project
    And admin ensures "pv-<%= project.name %>" pv is deleted after scenario
    Given cluster role "storage-admin" is added to the "first" user
    And I have a 1 GB volume and save volume id in the :volumeID clipboard

    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/ebs/pv-rwo.yaml"
    Then I replace lines in "pv-rwo.yaml":
      | ebs                           | pv-<%= project.name %> |
      | 10Gi                          | 1Gi                    |
      | aws://us-east-1d/vol-e69f0b1c | <%= cb.volumeID %>     |
    Then I run the :create client command with:
      | f | pv-rwo.yaml |
    And the step should succeed

    When I run the :get client command with:
      | resource | pv |
    Then the step should succeed
    And the output should contain:
      | pv-<%= project.name %> |

    When I run the :get client command with:
      | resource      | pv                     |
      | resource_name | pv-<%= project.name %> |
      | o             | yaml                   |
    Then the step should succeed

    When I run the :describe client command with:
      | resource | pv                     |
      | name     | pv-<%= project.name %> |
    Then the step should succeed

    Then I replace lines in "pv-rwo.yaml":
      | ReadWriteOnce | ReadWriteMany |

    When I run the :replace client command with:
      | f     | pv-rwo.yaml |
      | force | true        |
    And the step should succeed

    When I run the :describe client command with:
      | resource | pv                     |
      | name     | pv-<%= project.name %> |
    Then the step should succeed
    And the output should contain:
      | RWX |
    And the output should not contain:
      | RWO |

    When I run the :delete client command with:
      | object_type       | pv                    |
      | object_name_or_id | pv-<%=project.name %> |
    Then the step should succeed
    Then I wait for the resource "pv" named "pv-<%= project.name %>" to disappear within 60 seconds

  # @author chaoyang@redhat.com
  # @case_id OCP-10467
  @admin
  Scenario: OCP-10467 User with role storage-admin can get pvc object info
    Given I have a project
    And evaluation of `project.name` is stored in the :project clipboard

    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/ebs/dynamic-provisioning/pvc.yaml"
    And I replace lines in "pvc.yaml":
      | ebsc | pvc-<%= cb.project %> |
    And the step should succeed

    Then I run the :create client command with:
      | f | pvc.yaml |
    And the step should succeed

    Given I switch to the second user
    And cluster role "storage-admin" is added to the "second" user
    When I run the :get client command with:
      | resource | pvc               |
      | n        | <%= cb.project %> |
    And the step should succeed
    And the output should contain:
      | pvc-<%= cb.project %> |

    When I run the :describe client command with:
      | resource | pvc                   |
      | name     | pvc-<%= cb.project %> |
      | n        | <%= cb.project %>     |
    Then the step should succeed

    And I replace lines in "pvc.yaml":
      | ReadWriteOnce | ReadWriteMany |

    When I run the :replace client command with:
      | f     | pvc.yaml          |
      | force | true              |
      | n     | <%= cb.project %> |
    And the step should fail
    And the output should contain:
      | User "<%= user.name %>" cannot delete persistentvolumeclaims |

    When I run the :delete client command with:
      | object_type       | pvc                   |
      | object_name_or_id | pvc-<%= cb.project %> |
      | n                 | <%= cb.project %>     |
    And the step should fail
    And the output should contain:
      | User "<%= user.name %>" cannot delete persistentvolumeclaims |

  # @author chaoyang@redhat.com
  # @case_id OCP-10465
  Scenario: OCP-10465 Basic user could not get pv object info
    Given I have a project
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | pvc-<%= project.name %> |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound
    Then I run the :get client command with:
      | resource      | pv                     |
      | resource_name | <%= pvc.volume_name %> |
    And the step should fail
    And the output should contain:
      | User "<%= user.name %>" cannot get persistentvolumes at the cluster scope |

    When I run the :describe client command with:
      | resource | pv                     |
      | name     | <%= pvc.volume_name %> |
    And the step should fail
    And the output should contain:
      | User "<%= user.name %>" cannot get persistentvolumes at the cluster scope |

    When I run the :delete client command with:
      | object_type       | pv                     |
      | object_name_or_id | <%= pvc.volume_name %> |
    And the step should fail
    And the output should contain:
      | User "<%= user.name %>" cannot delete persistentvolumes at the cluster scope |

  # @author chuyu@redhat.com
  # @case_id OCP-9551
  Scenario: OCP-9551 User can know if he can create podspec against the current scc rules via CLI
    Given I have a project
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/tc538262/PodSecurityPolicySubjectReview_privileged_false.json"
    Then the step should succeed
    Given I run the :policy_scc_subject_review client command with:
      | f | PodSecurityPolicySubjectReview_privileged_false.json |
    Then the step should succeed
    And the output should match:
      | .*restricted |
    Given I run the :policy_scc_subject_review client command with:
      | f | PodSecurityPolicySubjectReview_privileged_false.json |
      | n | <%= project.name %>                                  |
    Then the step should succeed
    And the output should match:
      | .*restricted |
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/tc538262/PodSecurityPolicySubjectReview_privileged_true.json"
    Then the step should succeed
    Given I run the :policy_scc_subject_review client command with:
      | f | PodSecurityPolicySubjectReview_privileged_true.json |
    Then the step should succeed
    And the output should match:
      | <none> |
    Given I run the :policy_scc_subject_review client command with:
      | f | PodSecurityPolicySubjectReview_privileged_true.json |
      | n | <%= project.name %>                                 |
    Then the step should succeed
    And the output should match:
      | <none> |

  # @author chuyu@redhat.com
  # @case_id OCP-9552
  @admin
  Scenario: OCP-9552 User can know which serviceaccount and SA groups can create the podspec against the current sccs by CLI
    Given I have a project
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/tc538264/PodSecurityPolicyReview.json"
    Then the step should succeed
    Given I run the :policy_scc_review client command with:
      | f | PodSecurityPolicyReview.json |
    Then the step should succeed
    And the output should not match:
      | .*default.*restricted |
    Given I run the :policy_scc_review client command with:
      | f | PodSecurityPolicyReview.json |
      | n | <%= project.name %>          |
    Then the step should succeed
    And the output should not match:
      | .*default.*restricted |
    Given I run the :policy_scc_review client command with:
      | serviceaccount | default                      |
      | f              | PodSecurityPolicyReview.json |
    Then the step should succeed
    And the output should not match:
      | .*default.*restricted |
    Given I run the :policy_scc_review client command with:
      | serviceaccount | default                      |
      | f              | PodSecurityPolicyReview.json |
      | n              | <%= project.name %>          |
    Then the step should succeed
    And the output should not match:
      | .*default.*restricted |
    Given SCC "restricted" is added to the "default" service account
    Given I run the :policy_scc_review client command with:
      | f | PodSecurityPolicyReview.json |
    Then the step should succeed
    And the output should match:
      | .*default.*restricted |
    Given I run the :policy_scc_review client command with:
      | f | PodSecurityPolicyReview.json |
      | n | <%= project.name %>          |
    Then the step should succeed
    And the output should match:
      | .*default.*restricted |
    Given I run the :policy_scc_review client command with:
      | serviceaccount | default                      |
      | f              | PodSecurityPolicyReview.json |
    Then the step should succeed
    And the output should match:
      | .*default.*restricted |
    Given I run the :policy_scc_review client command with:
      | serviceaccount | default                      |
      | f              | PodSecurityPolicyReview.json |
      | n              | <%= project.name %>          |
    Then the step should succeed
    And the output should match:
      | .*default.*restricted |

  # @author chuyu@redhat.com
  # @case_id OCP-9553
  Scenario: OCP-9553 User can know whether the PodSpec he's describing will actually be allowed by the current SCC rules via CLI
    Given I have a project
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/tc538263/PodSecurityPolicySubjectReview.json"
    Then the step should succeed
    Given I run the :policy_scc_subject_review client command with:
      | user          | <%= user.name %>                    |
      | f             | PodSecurityPolicySubjectReview.json |
    Then the step should succeed
    And the output should not match:
      | .*restricted |
    Given I run the :policy_scc_subject_review client command with:
      | user | <%= user.name %>                    |
      | f    | PodSecurityPolicySubjectReview.json |
      | n    | <%= project.name %>                 |
    Then the step should succeed
    And the output should not match:
      | .*restricted |
    Given I run the :policy_scc_subject_review client command with:
      | user  | <%= user.name %>                    |
      | group | system:authenticated                |
      | f     | PodSecurityPolicySubjectReview.json |
    Then the step should succeed
    And the output should match:
      | .*restricted |
    Given I run the :policy_scc_subject_review client command with:
      | user  | <%= user.name %>                    |
      | group | system:authenticated                |
      | f     | PodSecurityPolicySubjectReview.json |
      | n     | <%= project.name %>                 |
    Then the step should succeed
    And the output should match:
      | .*restricted |

