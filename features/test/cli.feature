Feature: Testing CLI Scenarios

  Scenario: simple create project
    When I run the :new_project client command with:
      | project_name | demo |
      | display name | OpenShift 3 Demo |
      | description  | This is the first demo project with OpenShift v3 |
    Then the step should succeed
    And 3 seconds have passed
    When I run the :get client command with:
      | resource | projects |
    Then the step should succeed
    And the output should contain:
      | OpenShift 3 Demo |
      | Active |
    When I switch to the second user
    And I run the :get client command with:
      | resource | projects |
    Then the step should succeed
    And the output should not contain:
      | demo |
    When I switch to the first user
    And I run the :delete client command with:
      | object_type | project |
      | object_name_or_id | demo |
    Then the step should succeed

    # actually, because of user clean-up relying on cli, we never run REST
    #   requests before we run cli requests
  Scenario: rest request before cli
    Given I perform the :delete_project rest request with:
      | project name | demo |
    # looks like time needs to pass for the project to be really gone
    And 5 seconds have passed
    And I run the :get client command with:
      | resource | projects |
    Then the step should succeed
    And the output should not contain:
      | demo |

  Scenario: noescape, literal and false rules executor features
    When I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg | help create |
    # we fail because "help create" is treated as a single option
    Then the step should fail
    When I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg | noescape: help create |
    # here noescape prevents that
    Then the step should succeed
    When I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg | literal: :false |
    Then the step should fail
    And the output should contain:
      |unknown command ":false"|
    And the output should not contain:
      |:literal|
    When I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg             | help   |
      | test do not use | :false |
    Then the step should succeed
    And the output should match:
      |Developer .*? Client|

  Scenario: muti-args
    When I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg             | help   |
      | test do not use | create |
      | arg             | -h     |
    Then the step should succeed
    And the expression should be true> @result[:instruction] =~ /oc.+?help.+?create.+?-h/

  @test_bg
  Scenario: background and timeout 1
    Given the expression should be true> cb.start_time = Time.new
    When I run the :test_do_not_use client command with:
      | command  | sleep       |
      | opt      | 6030        |
      | opt      | noescape: # |
      | _timeout | 5           |
    And the expression should be true> cb.end_time = Time.new
    Then the step should fail
    And the output should not contain:
      | 6030 |
    And the expression should be true> @result[:timeout] == true
    # note that the process cleanup sequence takes more than 10 seconds
    And the expression should be true> cb.end_time - cb.start_time < 30

    When I run the :test_do_not_use background client command with:
      | command  | sleep |
      | opt      | 6030  |
      | opt      | noescape: # |
    Then the step should succeed
    # now check the sleep command is killed after scenario end

  @test_bg
  Scenario: background and timeout 2
    When I run the :test_do_not_use client command with:
      | command | ps  |
      | opt     | -ef |
      | opt     | noescape: # |
    Then the output should not contain:
      | 6030 |

  Scenario: try terminating background process
    When I run the :test_do_not_use background client command with:
      | command  | echo        |
      | opt      | foobarbaby  |
      | opt      | noescape: ; |
      | opt      | sleep       |
      | opt      | 6030        |
      | opt      | noescape: # |
    Given 3 seconds have passed
    And I terminate last background process
    Then the output should contain "foobarbaby"

  @unix
  Scenario: passing env variable to client commands
    When I run the :test_do_not_use client command with:
      | command  | bash                           |
      | opt      | -c                             |
      | opt      | echo $http_proxy               |
      | opt      | --                             |
      | _env     | http_proxy=http://myproxy:8888 |
    Then the step should succeed
    And the output should contain:
      | http://myproxy:8888 |


  Scenario: test times step change
    Given I have a project
    When I run the :new_build client command with:
      | code         | https://github.com/openshift/ruby-hello-world |
      | image_stream | openshift/ruby                                |
    Then the step should succeed
    And evaluation of `3` is stored in the :times clipboard
    Given I run the steps 3 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    Given the "ruby-hello-world-1" build becomes :running
    And I get project builds
    Then the output should contain 1 times:
      | Running |
    And the output should contain <%= cb.times %> times:
      | New     |
    When I run the :patch client command with:
      | resource      | buildconfig                                  |
      | resource_name | ruby-hello-world                             |
      | p             | {"spec": {"runPolicy" : "SerialLatestOnly"}} |
    Then the step should succeed
    Given I run the steps 2 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    Given the "ruby-hello-world-1" build completes
    And the "ruby-hello-world-6" build becomes :running
    And I get project builds
    Then the output should contain 1 times:
      | Complete  |
    And the output should contain 1 times:
      | Running   |
    And evaluation of `4` is stored in the :times clipboard
    And the output should match <%= cb.times %> times:
      | Git.*Cancelled |
    Given I run the steps 2 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    And the "ruby-hello-world-7" build becomes :cancelled
    Given I get project builds
    Then the output should contain 1 times:
      | Complete  |
    And the output should contain 1 times:
      | Running   |
    And evaluation of `5` is stored in the :times clipboard
    And the output should match <%= cb.times %> times:
      | Git.*Cancelled |
    And the output should contain 1 times:
      | New       |
    When I run the :patch client command with:
      | resource      | buildconfig                        |
      | resource_name | ruby-hello-world                   |
      | p             | {"spec": {"runPolicy" : "Serial"}} |
    Then the step should succeed
    Given I run the steps 2 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    Given I get project builds
    Then the output should contain 1 times:
      | Complete  |
    And the output should contain 1 times:
      | Running   |
    And the output should match <%= cb.times %> times:
      | Git.*Cancelled |
    And the output should contain 3 times:
      | New       |

