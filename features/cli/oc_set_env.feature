Feature: oc_set_env.feature

  # @author wewang@redhat.com
  # @case_id OCP-11248
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  Scenario: Set environment variables for resources using oc set env
    Given I have a project
    Given I obtain test data file "build/application-template-stibuild.json"
    When I run the :new_app client command with:
      | app_repo | application-template-stibuild.json |
    And the step succeeded
    # set one enviroment variable
    When I run the :set_env client command with:
      | resource | bc/ruby-sample-build |
      | e        | key=value     |
    Then the step should succeed
    When I run the :set_env client command with:
      | resource | bc/ruby-sample-build |
      | list     | true |
    Then the step should succeed
    And the output should contain:
      | key=value      |
    When I run the :set_env client command with:
      | resource | bc/ruby-sample-build |
      | e        | key=value,key1=value1,key2=value2 |
    Then the step should succeed
    When I run the :set_env client command with:
      | resource | bc/ruby-sample-build |
      | list     | true |
    Then the step should succeed
    And the output should contain:
      | key=value      |
      | key1=value1    |
      | key2=value2    |
    # set enviroment variable via STDIN
    When I run the :set_env client command with:
      | resource |  bc/ruby-sample-build  |
      | e        | -             |
      | _stdin   | key3=value3   |
    Then the step should succeed
    When I run the :set_env client command with:
      | resource | bc/ruby-sample-build |
      | list     | true |
    Then the step should succeed
    And the output should contain:
      | key=value      |
      | key1=value1    |
      | key2=value2    |
      | key3=value3    |
    # set invalid enviroment variable
    When I run the :set_env client command with:
      | resource | bc/ruby-sample-build |
      | e        | pe#cial%=1234 |
    Then the step should fail
   And the output should contain:
      | error |

  # @author wewang@redhat.com
  # @case_id OCP-10798
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @connected
  Scenario: Remove environment variables for resources using oc set env
    Given I have a project
    Given I obtain test data file "build/application-template-stibuild.json"
    When I run the :new_app client command with:
      | app_repo | application-template-stibuild.json |
    And the step succeeded
    # set environment variables
    When I run the :set_env client command with:
      | resource | bc/ruby-sample-build |
      | all      | true       |
      | e        |  FOO=bar   |
    Then the step succeeded
    # list environment variables
    When I run the :set_env client command with:
      | resource | bc/ruby-sample-build |
      | list     | true        |
    Then the step should succeed
    And the output should contain:
      | FOO=bar |
    # remove environment variables
    When I run the :set_env client command with:
      | resource | bc/ruby-sample-build  |
      | env_name | FOO-       |
    Then the step succeeded
    # list environment variables
    When I run the :set_env client command with:
      | resource | bc/ruby-sample-build |
      | list     | true        |
    Then the step should succeed
    And the output should not contain:
      | FOO=bar |
    #Remove variables in json file and update dc in server
    When I run the :get client command with:
      | resource | dc   |
      | o        | json |
    Then the step succeeded
    Given evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :dc_one clipboard
    Given evaluation of `@result[:parsed]['items'][1]['metadata']['name']` is stored in the :dc_two clipboard
    # set environment variables
    When I run the :set_env client command with:
      | resource | dc   |
      | all      | true |
      | e        | FOO=bar |
    Then the step succeeded
    When I run the :set_env client command with:
      | resource | dc   |
      | list     | true |
      | all      | true |
    Then the step should succeed
    And the output by order should match:
      | deploymentconfigs.*<%= cb.dc_one %> |
      | FOO=bar |
      | deploymentconfigs.*<%= cb.dc_two %> |
      | FOO=bar |
    #remove env from json and update service
    And I run the :get client command with:
      | resource      | dc                 |
      | o             | json               |
    Then the step should succeed
    When I save the output to file> dc.json
    When I run the :set_env client command with:
      | f        | dc.json   |
      | env_name | FOO- |
    Then the step should succeed
    When I run the :set_env client command with:
      | resource | dc   |
      | list     | true |
      | all      | true |
    And the output by order should not match:
      | deploymentconfigs.*<%= cb.dc_one %> |
      | FOO=bar |
      | deploymentconfigs.*<%= cb.dc_two %> |
      | FOO=bar |
    #Remove the environment variable ENV from container in all deployment configs
    When I run the :set_env client command with:
      | resource | dc/frontend |
      | c        | ruby-helloworld |
      | env_name | MYSQL_USER- |
    Then the step should succeed
    And the output should not contain:
      | MYSQL_USER= |

