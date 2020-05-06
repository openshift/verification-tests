Feature: Check Authentication operators and operands are upgraded correctly	

# @author pmali@redhat.com
@admin
@upgrade-prepare
Scenario: Check Authentication operators and operands are upgraded correctly - prepare
# According to our upgrade workflow, we need an upgrade-prepare and upgrade-check for each scenario.
# But some of them do not need any prepare steps, which lead to errors "can not find scenarios" in the log.
# So we just add a simple/useless step here to get rid of the errors in the log.
  Given the expression should be true> "True" == "True"

# @author pmali@redhat.com
# @case_id OCP-22734
@admin
@upgrade-check
Scenario: Check Authentication operators and operands are upgraded correctly	
  Given I switch to cluster admin pseudo user
  When I use the "default" project
  Then the "authentication" operator version matches the current cluster version

# Check the operator object has status for Degraded|Progressing|Available|Upgradeable
  And the expression should be true> cluster_operator('authentication').condition(type: 'Available')['status'] == "True"
  And the expression should be true> cluster_operator('authentication').condition(type: 'Degraded')['status'] == "False"
  And the expression should be true> cluster_operator('authentication').condition(type: 'Progressing')['status'] == "False"
  And the expression should be true> cluster_operator('authentication').condition(type: 'Upgradeable')['status'] == "True"
