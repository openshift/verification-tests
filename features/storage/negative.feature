Feature: negative testing

  # @author jhou@redhat.com
  # @author lxia@redhat.com
  @admin
  @4.8 @4.7 @4.6
  Scenario Outline: PV with invalid volume id should be prevented from creating
    Given admin ensures "mypv" pv is deleted after scenario
    Given I obtain test data file "storage/<dir>/<file>"
    When I run the :create admin command with:
      | f | <file> |
    Then the step should fail
    And the output should contain:
      | <error> |

    @singlenode
    @proxy @noproxy @disconnected @connected
    Examples:
      | dir | file               | error                        |
      | gce | pv-retain-rwx.json | error querying GCE PD volume | # @case_id OCP-10310
