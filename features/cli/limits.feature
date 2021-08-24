Feature: limit range related scenarios:

  # @author pruan@redhat.com
  # @author azagayno@redhat.com
  @admin
  @inactive
  Scenario Outline: Limit range default request tests
    Given I have a project
    Given I obtain test data file "limits/<path>/limit.yaml"
    When I run the :create admin command with:
      | f         | limit.yaml |
      | namespace | <%= project.name %>                                             |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | namespace           |
      | name     | <%= project.name %> |
    And the output should match:
      | <expr1> |
      | <expr2> |
    And admin ensures "limits" limit_range is deleted from the "<%= project.name %>" project

    Examples:
      | path     | expr1                                                | expr2                                                |
      | ocp10697 | Container\\s+cpu\\s+\-\\s+\-\\s+200m\\s+200m\\s+\-   | Container\\s+memory\\s+\-\\s+\-\\s+1Gi\\s+1Gi\\s+\-  | # @case_id OCP-10697
      | ocp11175 | Container\\s+cpu\\s+200m\\s+\-\\s+200m\\s+\-\\s+\-   | Container\\s+memory\\s+1Gi\\s+\-\\s+1Gi\\s+\-\\s+\-  | # @case_id OCP-11175
      | ocp11519 | Container\\s+cpu\\s+\-\\s+200m\\s+200m\\s+200m\\s+\- | Container\\s+memory\\s+\-\\s+1Gi\\s+1Gi\\s+1Gi\\s+\- | # @case_id OCP-11519

  # @author pruan@redhat.com
  # @author azagayno@redhat.com
  @admin
  Scenario Outline: Limit range invalid values tests
    Given I have a project
    Given I obtain test data file "limits/<path>/limit.yaml"
    When I run the :create admin command with:
      | f         | limit.yaml |
      | namespace | <%= project.name %>                                             |
    And the step should fail
    And the output should match:
      | LimitRange "limits" is invalid |
      | defaultRequest\[cpu\].* <expr2> value <expr3> is greater than <expr4> value <expr5> |
      | default\[cpu\].*<expr7> value <expr8> is greater than <expr9> value <expr10>       |
      | defaultRequest\[memory\].*<expr12> value <expr13> is greater than <expr14> value <expr15> |
      | default\[memory\].*<expr17> value <expr18> is greater than <expr19> value <expr20>         |

    Examples:
      | path | expr1 | expr2 | expr3 | expr4 | expr5 | expr6 | expr7 | expr8 | expr9 | expr10 | expr11 |expr12 | expr13| expr14 | expr15 | expr16 | expr17 | expr18 | expr19| expr20 |
      | ocp11745 | 400m | default request | 400m | max | 200m | 200m | default | 400m | max | 200m | 2Gi | default request | 2Gi | max | 1Gi | 1Gi | default | 2Gi  | max   | 1Gi    | # @case_id OCP-11745
      | ocp12200 | 200m | min | 400m | default request | 200m | 400m | min | 400m | default | 200m | 1Gi | min | 2Gi | default request | 1Gi | 2Gi | min | 2Gi  | default   | 1Gi    | # @case_id OCP-12200

  # @author pruan@redhat.com
  # @author azagayno@redhat.com
  # @case_id OCP-12286
  @admin
  Scenario Outline: Limit range incorrect values
    Given I have a project
    Given I obtain test data file "limits/<path>/limit.yaml"
    When I run the :create admin command with:
      | f         | limit.yaml |
      | namespace | <%= project.name %>                                             |
    And the step should fail
    And the output should match:
      | min\[memory\].*<expr2> value <expr3> is greater than <expr4> value <expr5> |
      | min\[cpu\].*<expr7> value <expr8> is greater than <expr9> value <expr10>   |

    Examples:
      | path | expr1 | expr2 | expr3 | expr4 | expr5 | expr6 | expr7 | expr8 | expr9 | expr10 |
      | ocp12286 | 2Gi | min | 2Gi | max | 1Gi | 400m | min | 400m | max | 200m |

  # @author pruan@redhat.com
  # @author azagayno@redhat.com
  # @case_id OCP-12250
  @admin
  Scenario: Limit range does not allow min > defaultRequest
    Given I have a project
    Given I obtain test data file "limits/ocp12250/limit.yaml"
    When I run the :create admin command with:
      | f         | limit.yaml |
      | namespace | <%= project.name %>                                               |
    Then the step should fail
    And the output should match:
      | cpu.*min value 400m is greater than default request value 200m  |
      | memory.*min value 2Gi is greater than default request value 1Gi |

  # @author gpei@redhat.com
  # @author azagayno@redhat.com
  # @case_id OCP-11918
  @admin
  Scenario: Limit range does not allow defaultRequest > default
    Given I have a project
    Given I obtain test data file "limits/ocp11918/limit.yaml"
    When I run the :create admin command with:
      | f         | limit.yaml |
      | namespace | <%= project.name %>                                               |
    Then the step should fail
    And the output should match:
      | cpu.*default request value 400m is greater than default limit value 200m  |
      | memory.*default request value 2Gi is greater than default limit value 1Gi |

  # @author gpei@redhat.com
  # @author azagayno@redhat.com
  # @case_id OCP-12043
  @admin
  Scenario: Limit range does not allow defaultRequest > max
    Given I have a project
    Given I obtain test data file "limits/ocp12043/limit.yaml"
    When I run the :create admin command with:
      | f         | limit.yaml |
      | namespace | <%= project.name %>                                               |
    Then the step should fail
    And the output should match:
      | cpu.*default request value 400m is greater than max value 200m  |
      | memory.*default request value 2Gi is greater than max value 1Gi |

  # @author gpei@redhat.com
  # @author azagayno@redhat.com
  # @case_id OCP-12139
  @admin
  Scenario: Limit range does not allow maxLimitRequestRatio > Limit/Request
    Given I have a project
    Given I obtain test data file "limits/ocp12139/limit.yaml"
    When I run the :create admin command with:
      | f         | limit.yaml |
      | namespace | <%= project.name %>                                               |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | namespace           |
      | name     | <%= project.name %> |
    Then the output should match:
      | Container\\s+cpu\\s+\-\\s+\-\\s+\-\\s+\-\\s+4    |
      | Container\\s+memory\\s+\-\\s+\-\\s+\-\\s+\-\\s+4 |
    Given I obtain test data file "limits/ocp12139/pod.yaml"
    When I run the :create client command with:
      | f | pod.yaml |
    Then the step should fail
    And the output should contain:
      | cpu max limit to request ratio per Container is 4, but provided ratio is 15.000000 |

  # @author gpei@redhat.com
  # @author azagayno@redhat.com
  # @case_id OCP-12315
  @admin
  Scenario: Limit range with all values set with proper values
    Given I have a project
    Given I obtain test data file "limits/ocp12315/limit.yaml"
    When I run the :create admin command with:
      | f         | limit.yaml |
      | namespace | <%= project.name %>                                               |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | namespace           |
      | name     | <%= project.name %> |
    Then the output should match:
      | Pod\\s+cpu\\s+20m\\s+960m\\s+\-\\s+\-\\s+\-                |
      | Pod\\s+memory\\s+10Mi\\s+1Gi\\s+\-\\s+\-\\s+\-             |
      | Container\\s+cpu\\s+10m\\s+480m\\s+180m\\s+240m\\s+4       |
      | Container\\s+memory\\s+5Mi\\s+512Mi\\s+128Mi\\s+256Mi\\s+4 |
    Given I obtain test data file "limits/ocp12315/pod.yaml"
    When I run the :create client command with:
      | f | pod.yaml |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I get project pod named "mypod" as YAML
    Then the output should match:
      | \\s+limits:\n\\s+cpu: 300m\n\\s+memory: 300Mi\n   |
      | \\s+requests:\n\\s+cpu: 100m\n\\s+memory: 100Mi\n |
    """
