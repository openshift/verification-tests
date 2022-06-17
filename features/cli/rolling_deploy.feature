Feature: rolling deployment related scenarios

  # @author pruan@redhat.com
  # @case_id OCP-12359
  Scenario: OCP-12359 Rolling-update pods with default value for maxSurge/maxUnavailable
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/rolling.json |
    And I wait for the pod named "hooks-1-deploy" to die
    Then I run the :scale client command with:
      | resource | dc    |
      | name     | hooks |
      | replicas | 3     |
    And 3 pods become ready with labels:
      | name=hello-openshift |
    And I wait up to 120 seconds for the steps to pass:
    """
    And I run the :get client command with:
      | resource | dc |
      | resource_name | hooks |
      | output | yaml |
    Then the output should contain:
      | replicas: 3  |
      | maxSurge: 25% |
      | maxUnavailable: 25%  |
    """
    When I run the :rollout_latest client command with:
      | resource | dc/hooks |
    Then the step should succeed
    And the pod named "hooks-2-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-2-deploy" until it disappears
    And the output should contain:
      | keep 3 pods available, don't exceed 4 pods |
    And I replace resource "dc" named "hooks":
      | maxUnavailable: 25% | maxUnavailable: 1 |
      | maxSurge: 25% | maxSurge: 2             |
    Then the step should succeed
    When I run the :rollout_latest client command with:
      | resource | dc/hooks |
    Then the step should succeed
    And the pod named "hooks-3-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-3-deploy" until it disappears
    And the output should contain:
      | keep 2 pods available, don't exceed 5 pods |

  # @author xiaocwan@redhat.com
  # @case_id OCP-11876
  Scenario: [origin_runtime_509]Rollback to two components of previous deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Recreate"     |
      | "type": "ConfigChange" |
      | "replicas": 1 |

    And I wait until the status of deployment "hooks" becomes :complete
    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Rolling"     |
      | "type": "ImageChange" |
      | "replicas": 2 |

    ## post rest request for curl new json
    And I wait until the status of deployment "hooks" becomes :complete
    When I perform the :rollback_deploy rest request with:
      | project_name            | <%= project.name %> |
      | deploy_name             | hooks-1 |
      | includeTriggers         | false |
      | includeTemplate         | true  |
      | includeReplicationMeta  | true  |
      | includeStrategy         | false |
    Then the step should succeed
    And the output should contain:
      | 201 |

    When I save the output to file>rollback.json
    And I run the :replace client command with:
      | f | rollback.json |
    Then the step should succeed
    And the output should contain:
      | replaced |

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "replicas": 1 |

  # @author xiaocwan@redhat.com
  # @case_id OCP-11071
  Scenario: [origin_runtime_509]Rollback to all components of previous deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Recreate"     |
      | "type": "ConfigChange" |
      | "replicas": 1 |

    And I wait until the status of deployment "hooks" becomes :complete
    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Rolling"     |
      | "type": "ImageChange" |
      | "replicas": 2 |

    ## post rest request for curl new json
    And I wait until the status of deployment "hooks" becomes :complete
    When I perform the :rollback_deploy rest request with:
      | project_name            | <%= project.name %> |
      | deploy_name             | hooks-1 |
      | includeTriggers         | true  |
      | includeTemplate         | true  |
      | includeReplicationMeta  | true  |
      | includeStrategy         | true  |
    Then the step should succeed
    And the output should contain:
      | 201 |
    When I save the output to file>rollback.json
    And I run the :replace client command with:
      | f | rollback.json |
    Then the step should succeed
    And the output should contain:
      | replaced |

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Recreate"     |
      | ConfigChange |
      | "replicas": 1 |

