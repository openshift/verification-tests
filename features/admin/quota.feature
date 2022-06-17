Feature: Quota related scenarios

  # @author qwang@redhat.com
  @admin
  Scenario Outline: The quota usage should be incremented if meet the following requirement
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/myquota.yaml |
      | n | <%= project.name %>                                                                   |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30      |
      |	memory\\s+0\\s+16Gi |
    """
    When I run oc create over ERB URL: https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/<path>/<file>
    Then the step should succeed
    And the pod named "<pod_name>" becomes ready
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | <expr1> |
      | <expr2> |

    Examples:
      | path     | file                           | pod_name                  | expr1             | expr2                       |
      | tc509090 | pod-request-limit-valid-3.yaml | pod-request-limit-valid-3 | cpu\\s+100m\\s+30 | memory\\s+(134217728\|128Mi)\\s+16Gi | # @case_id OCP-11754
      | tc509092 | pod-request-limit-valid-1.yaml | pod-request-limit-valid-1 | cpu\\s+500m\\s+30 | memory\\s+(536870912\|512Mi)\\s+16Gi | # @case_id OCP-12049
      | tc509093 | pod-request-limit-valid-2.yaml | pod-request-limit-valid-2 | cpu\\s+200m\\s+30 | memory\\s+(268435456\|256Mi)\\s+16Gi | # @case_id OCP-12145

  # @author qwang@redhat.com
  # @case_id OCP-12292
  @admin
  Scenario: OCP-12292 The quota usage should NOT be incremented if Requests and Limits aren't specified
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/myquota.yaml |
      | n | <%= project.name %>                                                                   |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30      |
      | memory\\s+0\\s+16Gi |
    """
    When I run oc create over ERB URL: https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/tc509096/pod-request-limit-invalid-1.yaml
    Then the step should fail
    And the output should match:
      | (?i)Failed quota: myquota: must specify cpu,memory |
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30      |
      | memory\\s+0\\s+16Gi |

  # @author qwang@redhat.com
  # @case_id OCP-12256
  @admin
  Scenario: OCP-12256 The quota usage should NOT be incremented if Requests > Limits
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/myquota.yaml |
      | n | <%= project.name %>                                                                   |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When  I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30      |
      | memory\\s+0\\s+16Gi |
    """
    When I run oc create over ERB URL: https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/tc509095/pod-request-limit-invalid-2.yaml
    Then the step should fail
    And the output should match:
      | Invalid value: "(5\|6)00m": must be (greater\|less) than or equal to( cpu)? (request\|limit)  |
      | Invalid value: "(256\|512)Mi": must be (greater\|less) than or equal to( memory)? (request\|limit) |
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30      |
      | memory\\s+0\\s+16Gi |
    """

  # @author qwang@redhat.com
  # @case_id OCP-12206
  @admin
  Scenario: OCP-12206 The quota usage should NOT be incremented if Requests = Limits but exceeding hard quota
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/myquota.yaml |
      | n | <%= project.name %>                                                                   |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When  I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30      |
      | memory\\s+0\\s+16Gi |
    """
    When I run oc create over ERB URL: https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/tc509094/pod-request-limit-invalid-3.yaml
    Then the step should fail
    And the output should match:
      | Error from server.*forbidden: (?i)Exceeded quota.* |
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30      |
      | memory\\s+0\\s+16Gi |

  # @author qwang@redhat.com
  # @case_id OCP-11566
  @admin
  Scenario: OCP-11566 The quota status is calculated ASAP when editing its quota spec
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/myquota.yaml |
      | n | <%= project.name %>                                                                   |
    Then the step should succeed
    When  I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu.*30                    |
      | memory.*16Gi               |
      | persistentvolumeclaims.*20 |
      | pods.*20                   |
      | replicationcontrollers.*30 |
      | resourcequotas.*1          |
      | secrets.*15                |
      | services.*10               |
    When I run the :patch admin command with:
      | resource | quota |
      | resource_name | myquota |
      | namespace | <%= project.name %> |
      | p | {"spec":{"hard":{"cpu":"40"}}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu.*40 |
    When I run the :patch admin command with:
      | resource | quota |
      | resource_name | myquota |
      | namespace | <%= project.name %> |
      | p | {"spec":{"hard":{"memory":"20Gi"}}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | memory.*20Gi |
    When I run the :patch admin command with:
      | resource | quota |
      | resource_name | myquota |
      | namespace | <%= project.name %> |
      | p | {"spec":{"hard":{"services":"100"}}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | services.*100 |

  # @author qwang@redhat.com
  # @case_id OCP-10801
  @admin
  Scenario: OCP-10801 Check BestEffort scope of resourcequota
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/quota-besteffort.yaml |
      | n | <%= project.name %> |
    Then the step should succeed
    When  I run the :describe client command with:
      | resource | quota            |
      | name     | quota-besteffort |
    Then the output should match:
      | Scopes:\\s+BestEffort |
      | pods\\s+0\\s+2        |
    # For BestEffort pod
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-besteffort.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota            |
      | name     | quota-besteffort |
    Then the output should match:
      | pods\\s+1\\s+2 |
    Given I ensure "pod-besteffort" pod is deleted
    # Because quota optimation is under way, leave time gap to wait for operation completed
    And I wait for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | quota            |
      | name     | quota-besteffort |
    Then the output should match:
      | pods\\s+0\\s+2 |
    """
    # For Bustable pod
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-notbesteffort.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota            |
      | name     | quota-besteffort |
    Then the output should match:
      | pods\\s+0\\s+2 |
    Given I ensure "pod-notbesteffort" pod is deleted
    When I run the :describe client command with:
      | resource | quota            |
      | name     | quota-besteffort |
    Then the output should match:
      | pods\\s+0\\s+2 |

  # @author qwang@redhat.com
  # @case_id OCP-11251
  @admin
  Scenario: OCP-11251 Check NotBestEffort scope of resourcequota
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/quota-notbesteffort.yaml |
      | n | <%= project.name %> |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota               |
      | name     | quota-notbesteffort |
    Then the output should match:
      | Scopes:\\s+NotBestEffort    |
      | limits.cpu\\s+0\\s+4        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+2              |
      | requests.cpu\\s+0\\s+2      |
      | requests.memory\\s+0\\s+1Gi |
    # For Bustable pod
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-notbesteffort.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota               |
      | name     | quota-notbesteffort |
    Then the output should match:
      | limits.cpu\\s+500m\\s+4         |
      | limits.memory\\s+256Mi\\s+2Gi   |
      | pods\\s+1\\s+2                  |
      | requests.cpu\\s+200m\\s+2       |
      | requests.memory\\s+256Mi\\s+1Gi |
    Given I ensure "pod-notbesteffort" pod is deleted
    # Because quota optimation is under way, leave time gap to wait for operation completed
    And I wait for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | quota               |
      | name     | quota-notbesteffort |
    Then the output should match:
      | limits.cpu\\s+0\\s+4        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+2              |
      | requests.cpu\\s+0\\s+2      |
      | requests.memory\\s+0\\s+1Gi |
    """
    # For BestEffort pod
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-besteffort.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota               |
      | name     | quota-notbesteffort |
    Then the output should match:
      | limits.cpu\\s+0\\s+4        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+2              |
      | requests.cpu\\s+0\\s+2      |
      | requests.memory\\s+0\\s+1Gi |
    Given I ensure "pod-besteffort" pod is deleted
    When I run the :describe client command with:
      | resource | quota               |
      | name     | quota-notbesteffort |
    Then the output should match:
      | limits.cpu\\s+0\\s+4        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+2              |
      | requests.cpu\\s+0\\s+2      |
      | requests.memory\\s+0\\s+1Gi |

  # @author qwang@redhat.com
  # @case_id OCP-11568
  @admin
  Scenario: OCP-11568 Check NotTerminating scope of resourcequota
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/quota-notterminating.yaml |
      | n | <%= project.name %> |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota                |
      | name     | quota-notterminating |
    Then the output should match:
      | Scopes:\\s+NotTerminating     |
      | .*not have an active deadline |
      | limits.cpu\\s+0\\s+4          |
      | limits.memory\\s+0\\s+2Gi     |
      | pods\\s+0\\s+2                |
      | requests.cpu\\s+0\\s+2        |
      | requests.memory\\s+0\\s+1Gi   |
    # For NotTerminating pod
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-notterminating.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota                |
      | name     | quota-notterminating |
    Then the output should match:
      | limits.cpu\\s+500m\\s+4         |
      | limits.memory\\s+256Mi\\s+2Gi   |
      | pods\\s+1\\s+2                  |
      | requests.cpu\\s+200m\\s+2       |
      | requests.memory\\s+256Mi\\s+1Gi |
    Given I ensure "pod-notterminating" pod is deleted
    # Because quota optimation is under way, leave time gap to wait for operation completed
    And I wait for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | quota                |
      | name     | quota-notterminating |
    Then the output should match:
      | limits.cpu\\s+0\\s+4        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+2              |
      | requests.cpu\\s+0\\s+2      |
      | requests.memory\\s+0\\s+1Gi |
    """
    # For Terminating pod
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-terminating.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota                |
      | name     | quota-notterminating |
    Then the output should match:
      | limits.cpu\\s+0\\s+4        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+2              |
      | requests.cpu\\s+0\\s+2      |
      | requests.memory\\s+0\\s+1Gi |
    Given I ensure "pod-terminating" pod is deleted
    When I run the :describe client command with:
      | resource | quota                |
      | name     | quota-notterminating |
    Then the output should match:
      | limits.cpu\\s+0\\s+4        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+2              |
      | requests.cpu\\s+0\\s+2      |
      | requests.memory\\s+0\\s+1Gi |

  # @author qwang@redhat.com
  # @case_id OCP-11780
  @admin
  Scenario: OCP-11780 Check Terminating scope of resourcequota
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/quota-terminating.yaml |
      | n | <%= project.name %> |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota             |
      | name     | quota-terminating |
    Then the output should match:
      | Scopes:\\s+Terminating         |
      | .*that have an active deadline |
      | limits.cpu\\s+0\\s+2           |
      | limits.memory\\s+0\\s+2Gi      |
      | pods\\s+0\\s+4                 |
      | requests.cpu\\s+0\\s+1         |
      | requests.memory\\s+0\\s+1Gi    |
    # For Terminating pod
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-terminating.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota             |
      | name     | quota-terminating |
    Then the output should match:
      | limits.cpu\\s+500m\\s+2         |
      | limits.memory\\s+256Mi\\s+2Gi   |
      | pods\\s+1\\s+4                  |
      | requests.cpu\\s+200m\\s+1       |
      | requests.memory\\s+256Mi\\s+1Gi |
    # activeDeadlineSeconds=60s, after 60s, used quota returns to the original state
    Given I wait for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | quota             |
      | name     | quota-terminating |
    Then the output should match:
      | limits.cpu\\s+0\\s+2        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+4              |
      | requests.cpu\\s+0\\s+1      |
      | requests.memory\\s+0\\s+1Gi |
    """
    Given I ensure "pod-terminating" pod is deleted
    When I run the :describe client command with:
      | resource | quota             |
      | name     | quota-terminating |
    Then the output should match:
      | limits.cpu\\s+0\\s+2        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+4              |
      | requests.cpu\\s+0\\s+1      |
      | requests.memory\\s+0\\s+1Gi |
    # For NotTerminating pod
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-notterminating.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota             |
      | name     | quota-terminating |
    Then the output should match:
      | limits.cpu\\s+0\\s+2        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+4              |
      | requests.cpu\\s+0\\s+1      |
      | requests.memory\\s+0\\s+1Gi |
    Given I ensure "pod-notterminating" pod is deleted
    When I run the :describe client command with:
      | resource | quota             |
      | name     | quota-terminating |
    Then the output should match:
      | limits.cpu\\s+0\\s+2        |
      | limits.memory\\s+0\\s+2Gi   |
      | pods\\s+0\\s+4              |
      | requests.cpu\\s+0\\s+1      |
      | requests.memory\\s+0\\s+1Gi |

  # @author chezhang@redhat.com
  # @case_id OCP-10706
  @admin
  Scenario: OCP-10706 Could create quota if existing resources exceed to the hard quota but prevent to create further resources
    Given I have a project
    When I run the :new_app admin command with:
      | file  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/quota_template.yaml |
      | param | CPU_VALUE=0.2  |
      | param | MEM_VALUE=1Gi  |
      | param | PV_VALUE=1     |
      | param | POD_VALUE=2    |
      | param | RC_VALUE=3     |
      | param | RQ_VALUE=3     |
      | param | SECRET_VALUE=5 |
      | param | SVC_VALUE=5    |
      | n     | <%= project.name %>            |
    Then the step should succeed
    When  I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+200m                 |
      | memory\\s+0\\s+1Gi               |
      | persistentvolumeclaims\\s+0\\s+1 |
      | pods\\s+0\\s+2                   |
      | replicationcontrollers\\s+0\\s+3 |
      | resourcequotas\\s+1\\s+3         |
      | secrets\\s+9\\s+5                |
      | services\\s+0\\s+5               |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/tc509087/mysecret.json |
    Then the step should fail
    And the output should match:
      | Error from server.*forbidden: (?i)Exceeded quota.* |
    When I run the :patch admin command with:
      | resource | quota |
      | resource_name | myquota |
      | namespace | <%= project.name %> |
      | p | {"spec":{"hard":{"secrets":"15"}}} |
    Then the step should succeed
    When  I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+200m                 |
      | memory\\s+0\\s+1Gi               |
      | persistentvolumeclaims\\s+0\\s+1 |
      | pods\\s+0\\s+2                   |
      | replicationcontrollers\\s+0\\s+3 |
      | resourcequotas\\s+1\\s+3         |
      | secrets\\s+9\\s+15               |
      | services\\s+0\\s+5               |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/tc509087/mysecret.json |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+200m                 |
      | memory\\s+0\\s+1Gi               |
      | persistentvolumeclaims\\s+0\\s+1 |
      | pods\\s+0\\s+2                   |
      | replicationcontrollers\\s+0\\s+3 |
      | resourcequotas\\s+1\\s+3         |
      | secrets\\s+10\\s+15              |
      | services\\s+0\\s+5               |

  # @author chezhang@redhat.com
  # @case_id OCP-11779
  @admin
  Scenario: OCP-11779 The usage for cpu/mem/pod counts are fixed up ASAP if delete a pod
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/myquota.yaml |
      | n | <%= project.name %>    |
    Then the step should succeed
    When  I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30                    |
      | memory\\s+0\\s+16Gi               |
      | persistentvolumeclaims\\s+0\\s+20 |
      | pods\\s+0\\s+20                   |
      | replicationcontrollers\\s+0\\s+30 |
      | resourcequotas\\s+1\\s+1          |
      | secrets\\s+9\\s+15                |
      | services\\s+0\\s+10               |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/tc519922/pod-request-limit-valid-4.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+400m\\s+30                 |
      | memory\\s+1Gi\\s+16Gi             |
      | persistentvolumeclaims\\s+0\\s+20 |
      | pods\\s+1\\s+20                   |
      | replicationcontrollers\\s+0\\s+30 |
      | resourcequotas\\s+1\\s+1          |
      | secrets\\s+9\\s+15                |
      | services\\s+0\\s+10               |
    Given I ensure "pod-request-limit-valid-4" pod is deleted
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30                    |
      | memory\\s+0\\s+16Gi               |
      | persistentvolumeclaims\\s+0\\s+20 |
      | pods\\s+0\\s+20                   |
      | replicationcontrollers\\s+0\\s+30 |
      | resourcequotas\\s+1\\s+1          |
      | secrets\\s+9\\s+15                |
      | services\\s+0\\s+10               |
    """

  # @author cryan@redhat.com
  # @case_id OCP-10033
  # @bug_id 1333122
  @admin
  Scenario: OCP-10033 Quota events for compute resource failures shouldn't be redundant
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc528448/quota.yaml |
      | n | <%= project.name %>                                                                              |
    Then the step should succeed
    Given I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc528448/sample-app-database-dc-resources-large-invalid.json"
    Then the step should succeed
    Given I wait until the status of deployment "database" becomes :failed
    When I run the :get client command with:
      | resource | event               |
      | n        | <%= project.name %> |
    Then the step should succeed
    And the output should match:
      | pods "database-1-hook-mid" is forbidden: exceeded quota |
      | pods "database-1-hook-pre" is forbidden: exceeded quota |
      | pods "database-1-(.{5})?" is forbidden: exceeded quota  |
    And the output should not contain 3 times:
      | pods "database-1-hook-mid" is forbidden: exceeded quota |
      | pods "database-1-hook-pre" is forbidden: exceeded quota |

  # @author qwang@redhat.com
  # @case_id OCP-11247
  @admin
  Scenario: OCP-11247 The current quota usage is calculated ASAP when adding a quota
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/myquota.yaml |
      | n | <%= project.name %>    |
    Then the step should succeed
    When  I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30                    |
      | memory\\s+0\\s+16Gi               |
      | persistentvolumeclaims\\s+0\\s+20 |
      | pods\\s+0\\s+20                   |
      | replicationcontrollers\\s+0\\s+30 |
      | resourcequotas\\s+1\\s+1          |
      | secrets\\s+9\\s+15                |
      | services\\s+0\\s+10               |
    # Add correct quota
    When I run the :patch admin command with:
      | resource      | quota                          |
      | resource_name | myquota                        |
      | namespace     | <%= project.name %>            |
      | p             | {"spec":{"hard":{"cpu":"31","memory":"20Gi","persistentvolumeclaims":"30","pods":"50","replicationcontrollers":"10","resourcequotas":"2","secrets":"20","services":"30"}}} |
    Then the step should succeed
    And I wait up to 5 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+31                    |
      | memory\\s+0\\s+20Gi               |
      | persistentvolumeclaims\\s+0\\s+30 |
      | pods\\s+0\\s+50                   |
      | replicationcontrollers\\s+0\\s+10 |
      | resourcequotas\\s+1\\s+2          |
      | secrets\\s+9\\s+20                |
      | services\\s+0\\s+30               |
    """

  # @author qwang@redhat.com
  # @case_id OCP-11927
  @admin
  Scenario: OCP-11927 The quota usage should be incremented if Requests = Limits and in the range of hard quota but exceed the real node available resources
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/myquota.yaml |
      | n | <%= project.name %>    |
    Then the step should succeed
    When  I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+0\\s+30                    |
      | memory\\s+0\\s+16Gi               |
      | persistentvolumeclaims\\s+0\\s+20 |
      | pods\\s+0\\s+20                   |
      | replicationcontrollers\\s+0\\s+30 |
      | resourcequotas\\s+1\\s+1          |
      | secrets\\s+9\\s+15                |
      | services\\s+0\\s+10               |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/tc509091/pod-request-limit-valid-4.yaml |
    Then the step should succeed
    Given the pod named "pod-request-limit-valid-4" status becomes :pending
    When I run the :describe client command with:
      | resource | quota   |
      | name     | myquota |
    Then the output should match:
      | cpu\\s+10\\s+30                   |
      | memory\\s+10Gi\\s+16Gi            |
      | persistentvolumeclaims\\s+0\\s+20 |
      | pods\\s+1\\s+20                   |
      | replicationcontrollers\\s+0\\s+30 |
      | resourcequotas\\s+1\\s+1          |
      | secrets\\s+9\\s+15                |
      | services\\s+0\\s+10               |

  # @author chezhang@redhat.com
  # @case_id OCP-10945
  @admin
  Scenario: OCP-10945 The quota usage should be released when pod completed
    Given I have a project
    When I run the :create_quota admin command with:
      | name | myquota                    |
      | hard | cpu=30,memory=16Gi,pods=20 |
      | n    | <%= project.name %>        |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota    |
      | name     | myquota  |
    Then the output should match:
      | cpu\\s+0\\s+30      |
      | memory\\s+0\\s+16Gi |
      | pods\\s+0\\s+20     |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-completed.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota    |
      | name     | myquota  |
    Then the output should match:
      | cpu\\s+700m\\s+30     |
      | memory\\s+1Gi\\s+16Gi |
      | pods\\s+1\\s+20       |
    Given the pod named "podtocomplete" status becomes :succeeded
    When I run the :describe client command with:
      | resource | quota    |
      | name     | myquota  |
    Then the output should match:
      | cpu\\s+0\\s+30      |
      | memory\\s+0\\s+16Gi |
      | pods\\s+0\\s+20     |

  # @author chezhang@redhat.com
  # @case_id OCP-11983
  @admin
  Scenario: OCP-11983 Quota with BestEffort and NotBestEffort scope
    Given I have a project
    When I run the :create_quota admin command with:
      | name   | quota-besteffort     |
      | hard   | pods=10              |
      | scopes | BestEffort           |
      | n      | <%= project.name %>  |
    Then the step should succeed
    When I run the :create_quota admin command with:
      | name   | quota-notbesteffort |
      | hard   | pods=5              |
      | scopes | NotBestEffort       |
      | n | <%= project.name %>      |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota    |
    Then the output by order should match:
      | quota-besteffort    |
      | BestEffort          |
      | pods\\s+0\\s+10     |
      | quota-notbesteffort |
      | NotBestEffort       |
      | pods\\s+0\\s+5      |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-besteffort.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota    |
    Then the output by order should match:
      | pods\\s+1\\s+10     |
      | pods\\s+0\\s+5      |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-notbesteffort.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota    |
    Then the output by order should match:
      | pods\\s+1\\s+10     |
      | pods\\s+1\\s+5      |
    Given I ensure "pod-notbesteffort" pod is deleted
    When I run the :describe client command with:
      | resource | quota    |
    Then the output by order should match:
      | pods\\s+1\\s+10     |
      | pods\\s+0\\s+5      |

  # @author chezhang@redhat.com
  # @case_id OCP-12086
  @admin
  Scenario: OCP-12086 Quota with Terminating and NotTerminating scope
    Given I have a project
    When I run the :create_quota admin command with:
      | name   | quota-terminating |
      | hard   | pods=10           |
      | scopes | Terminating       |
      | n | <%= project.name %>    |
    Then the step should succeed
    When I run the :create_quota admin command with:
      | name   | quota-notterminating |
      | hard   | pods=5               |
      | scopes | NotTerminating       |
      | n      | <%= project.name %>  |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota     |
    Then the output by order should match:
      | quota-notterminating |
      | NotTerminating       |
      | pods\\s+0\\s+5       |
      | quota-terminating    |
      | Terminating          |
      | pods\\s+0\\s+10      |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-terminating.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota |
    Then the output by order should match:
      | pods\\s+0\\s+5   |
      | pods\\s+1\\s+10  |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-notterminating.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota |
    Then the output by order should match:
      | pods\\s+1\\s+5   |
      | pods\\s+1\\s+10  |
    Given a pod becomes ready with labels:
      | name=pod-terminating |
    And I wait up to 70 seconds for the steps to pass:
    """
    When I get project pods
    Then the output should match "pod-terminating.*DeadlineExceeded"
    """
    When I run the :describe client command with:
      | resource | quota |
    Then the output by order should match:
      | pods\\s+1\\s+5   |
      | pods\\s+0\\s+10  |

  # @author chezhang@redhat.com
  # @case_id OCP-11348
  @admin
  Scenario: OCP-11348 Quota combined scopes
    Given I have a project
    When I run the :create_quota admin command with:
      | name   | quota-notbesteffortandnotterminating |
      | hard   | pods=10                              |
      | scopes | NotBestEffort,NotTerminating         |
      | n | <%= project.name %>                       |
    Then the step should succeed
    When I run the :create_quota admin command with:
      | name   | quota-besteffortandterminating |
      | hard   | pods=8                         |
      | scopes | BestEffort,Terminating         |
      | n      | <%= project.name %>            |
    Then the step should succeed
    When I run the :create_quota admin command with:
      | name   | quota-besteffort    |
      | hard   | pods=6              |
      | scopes | BestEffort          |
      | n      | <%= project.name %> |
    Then the step should succeed
    When I run the :create_quota admin command with:
      | name   | quota-notterminating |
      | hard   | pods=5               |
      | scopes | NotTerminating       |
      | n      | <%= project.name %>  |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota |
    Then the output by order should match:
      | quota-besteffort                     |
      | BestEffort                           |
      | pods\\s+0\\s+6                       |
      | quota-besteffortandterminating       |
      | BestEffort.*Terminating              |
      | pods\\s+0\\s+8                       |
      | quota-notbesteffortandnotterminating |
      | NotBestEffort.*NotTerminating        |
      | pods\s+0\\s+10                       |
      | quota-notterminating                 |
      | NotTerminating                       |
      | pods\\s+0\\s+5                       |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-notbesteffort.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota |
    Then the output by order should match:
      | pods\\s+0\\s+6 |
      | pods\\s+0\\s+8 |
      | pods\s+1\\s+10 |
      | pods\\s+1\\s+5 |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-besteffort.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota |
    Then the output by order should match:
      | pods\\s+1\\s+6 |
      | pods\\s+0\\s+8 |
      | pods\s+1\\s+10 |
      | pods\\s+2\\s+5 |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pod-besteffort-terminating.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota |
    Then the output by order should match:
      | pods\\s+2\\s+6 |
      | pods\\s+1\\s+8 |
      | pods\s+1\\s+10 |
      | pods\\s+2\\s+5 |
    Given a pod becomes ready with labels:
      | name=pod-besteffort-terminating |
    And I wait up to 70 seconds for the steps to pass:
    """
    When I get project pods
    Then the output should match "pod-besteffort-terminating.*DeadlineExceeded"
    """
    When I run the :describe client command with:
      | resource | quota |
    Then the output by order should match:
      | pods\\s+1\\s+6 |
      | pods\\s+0\\s+8 |
      | pods\s+1\\s+10 |
      | pods\\s+2\\s+5 |

  # @author qwang@redhat.com
  # @case_id OCP-11636
  @admin
  Scenario: OCP-11636 Quota scope conflict BestEffort and NotBestEffort
    Given I have a project
    When I run the :create_quota admin command with:
      | name   | quota-besteffortnot      |
      | hard   | pods=10                  |
      | scopes | BestEffort,NotBestEffort |
      | n      | <%= project.name %>      |
    Then the step should fail
    And the output should match "Invalid value.*BestEffort.*NotBestEffort.*conflicting scopes"

  # @author qwang@redhat.com
  # @case_id OCP-11827
  @admin
  Scenario: OCP-11827 Quota scope conflict Terminating and NotTerminating
    Given I have a project
    When I run the :create_quota admin command with:
      | name   | quota-terminatingnot       |
      | hard   | pods=10                    |
      | scopes | Terminating,NotTerminating |
      | n      | <%= project.name %>        |
    Then the step should fail
    And the output should match "Invalid value.*Terminating.*NotTerminating.*conflicting scopes"

  # @author qwang@redhat.com
  # @case_id OCP-11000
  @admin
  Scenario: OCP-11000 Negative test for requests.storage of quota
    Given I have a project
    When I run the :create_quota admin command with:
      | name   | my-quota             |
      | hard   | requests.storage=1.5 |
      | n      | <%= project.name %>  |
    Then the step should succeed
    When I run the :create_quota admin command with:
      | name   | my-quota-1             |
      | hard   | requests.storage=1/2Gi |
      | n      | <%= project.name %>    |
    Then the step should fail
    And the output should contain "quantities must match the regular expression"
    When I run the :create_quota admin command with:
      | name   | my-quota-2            |
      | hard   | requests.storage=-2Gi |
      | n      | <%= project.name %>   |
    Then the step should fail
    And the output should contain "must be greater than or equal to 0"
    When I run the :create_quota admin command with:
      | name   | my-quota-3             |
      | hard   | requests.storage=abcGi |
      | n      | <%= project.name %>    |
    Then the step should fail
    And the output should contain "quantities must match the regular expression"
    When I run the :create_quota admin command with:
      | name   | my-quota-4          |
      | hard   | requests.storage=   |
      | n      | <%= project.name %> |
    Then the step should fail
    And the output should contain "quantities must match the regular expression"
    When I run the :describe client command with:
      | resource  | quota    |
    Then the output should match:
      | requests.storage\\s+0\\s+1500m |
    And the output should not contain:
      | my-quota-1 |
      | my-quota-2 |
      | my-quota-3 |
      | my-quota-4 |

  # @author qwang@redhat.com
  # @case_id OCP-10283
  @admin
  Scenario: OCP-10283 Annotation selector supports special characters
    Given I have a project
    Given admin ensures "crq-<%= project.name %>" cluster_resource_quota is deleted after scenario
    When I run the :create_clusterresourcequota admin command with:
      | name                | crq-<%= project.name %>                             |
      | hard                | pods=10                                             |
      | annotation-selector | openshift.io/requester=usertest~!#%^&*1@example.com |
    Then the step should succeed
    When I run the :annotate admin command with:
      | resource     | namespace                                           |
      | resourcename | <%= project.name %>                                 |
      | overwrite    | true                                                |
      | keyval       | openshift.io/requester=usertest~!#%^&*1@example.com |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json |
      | n | <%= project.name %> |
    Then the step should succeed
    When I run the :describe admin command with:
      | resource | clusterresourcequotas   |
      | name     | crq-<%= project.name %> |
    Then the output should match:
      | openshift.io/requester:usertest\~\!\#\%\^\&\*1@example.com |
      | pods\\s+1\\s+10                                            |

  # @author qwang@redhat.com
  # @case_id OCP-11660
  @admin
  Scenario: OCP-11660 Quota requests.storage with PVC existing
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rox.json |
      | n | <%= project.name %>                                                                                      |
    Then the step should succeed
    # Create requests.storage of quota < existing PVC capacity
    When I run the :create_quota admin command with:
      | name | quota-pvc-storage-1  |
      | hard | requests.storage=2Gi |
      | n    | <%= project.name %>  |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota               |
      | name     | quota-pvc-storage-1 |
      | n        | <%= project.name %> |
    Then the output should match:
      | requests.storage\\s+5Gi\\s+2Gi    |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rox.json" replacing paths:
      | ["metadata"]["name"] | pvc-2 |
    Then the step should fail
    And the output should contain:
      | persistentvolumeclaims "pvc-2" is forbidden: exceeded quota: quota-pvc-storage-1, requested: requests.storage=5Gi, used: requests.storage=5Gi, limited: requests.storage=2Gi |
    # Create requests.storage of quota > existing PVC capacity
    When I run the :create_quota admin command with:
      | name | quota-pvc-storage-2                             |
      | hard | requests.storage=10Gi,persistentvolumeclaims=50 |
      | n    | <%= project.name %>                             |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota               |
      | n        | <%= project.name %> |
    Then the output should match:
      | requests.storage\\s+5Gi\\s+2Gi    |
      | persistentvolumeclaims\\s+1\\s+50 |
      | requests.storage\\s+5Gi\\s+10Gi   |
    Given I ensure "nfsc" pvc is deleted
    When I run the :describe client command with:
      | resource | quota               |
      | n        | <%= project.name %> |
    Then the output should match:
      | requests.storage\\s+0\\s+2Gi      |
      | persistentvolumeclaims\\s+0\\s+50 |
      | requests.storage\\s+0\\s+10Gi     |

  # @author qwang@redhat.com
  # @case_id OCP-11389
  @admin
  Scenario: OCP-11389 Prevent creating further PVC if existing PVC exceeds the quota of requests.storage
    Given I have a project
    # Only quota requests.storage < 5Gi
    When I run the :create_quota admin command with:
      | name | quota-pvc-storage  |
      | hard | requests.storage=2Gi |
      | n    | <%= project.name %>  |
    Then the step should succeed
    # Create PVC (here request 5Gi storage)
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rox.json |
      | n | <%= project.name %>                                                                                      |
    Then the step should fail
    And the output should contain:
      | persistentvolumeclaims "nfsc" is forbidden: exceeded quota: quota-pvc-storage, requested: requests.storage=5Gi, used: requests.storage=0, limited: requests.storage=2Gi |
    When I run the :describe client command with:
      | resource | quota               |
      | n        | <%= project.name %> |
    Then the output should match:
      | requests.storage\\s+0\\s+2Gi    |
    When I run the :delete admin command with:
      | object_type       | quota               |
      | object_name_or_id | quota-pvc-storage   |
      | n           | <%= project.name %> |
    Then the step should succeed
    # Quota covers requests.storage > 5Gi and PVC
    When I run the :create_quota admin command with:
      | name | quota-pvc-storage                              |
      | hard | requests.storage=8Gi,persistentvolumeclaims=50 |
      | n    | <%= project.name %>                            |
    Then the step should succeed
    # Create PVC (here request 5Gi storage)
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rox.json |
      | n | <%= project.name %>                                                                                      |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota               |
      | n        | <%= project.name %> |
    Then the output should match:
      | persistentvolumeclaims\\s+1\\s+50 |
      | requests.storage\\s+5Gi\\s+8Gi    |
    # Create PVC again (here request 5Gi storage > avaliable quota 3Gi)
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rox.json" replacing paths:
      | ["metadata"]["name"] | pvc-2 |
    Then the step should fail
    And the output should contain:
      | persistentvolumeclaims "pvc-2" is forbidden: exceeded quota: quota-pvc-storage, requested: requests.storage=5Gi, used: requests.storage=5Gi, limited: requests.storage=8Gi |

  # @author qwang@redhat.com
  # @case_id OCP-12820
  @admin
  @destructive
  Scenario: OCP-12820 Precious resources should be denied in the absence of a covering quota if they are configured on the master
    # Modify master-config to set default resource limits
    Given master config is merged with the following hash:
    """
    admissionConfig:
      pluginConfig:
        ResourceQuota:
          configuration:
            apiVersion: resourcequota.admission.k8s.io/v1alpha1
            kind: Configuration
            limitedResources:
            - resource: persistentvolumeclaims
              matchContains:
              - .storageclass.storage.k8s.io/requests.storage
    """
    And the master service is restarted on all master nodes
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pvc-storage-class.json |
    Then the step should fail
    And the output should contain:
      | insufficient quota to consume: gold.storageclass.storage.k8s.io/requests.storage |
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/pvc-storage-class.json"
    And I replace lines in "pvc-storage-class.json":
      | pvc-storage-class | pvc-storage-class-1 |
      | gold              | silver              |
    When I run the :create client command with:
      | f | pvc-storage-class.json |
      | n | <%= project.name %>    |
    Then the step should fail
    And the output should contain:
      | insufficient quota to consume: silver.storageclass.storage.k8s.io/requests.storage |

