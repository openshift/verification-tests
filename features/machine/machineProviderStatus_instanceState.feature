Feature: Machine instance state annotation should be consistent

# @author miyadav@redhat.com
# @case_id OCP-27627

@admin
Scenario: Verify all machine instance-state in consistent with their providerStats.instanceState

 Given I have an IPI deployment

 When I run the :get admin command with:
      | resource  | machines                           |
      | namespace | openshift-machine-api |
      | o         | jsonpath='{range .items[*]}{.metadata.annotations}{"/\t"}{.status.providerStatus.instanceState}{"/\\n"}{end}'|

And evaluation of `@result[:response].split(":")` is stored in the :console_output_array clipboard
#Evaluating Result for each line

When I repeat the following steps for each :console_output in cb.console_output_array:

   """

   And evaluation of `cb.console_output.split(":")[1]` is stored in the :provider_status clipboard
   And evaluation of `cb.console_output.split("]")[1]` is stored in the :instance_status clipboard

   Then the expression should be true> cb.providerStatus == cb.instanceStatus

   """

Then the step should succeed

