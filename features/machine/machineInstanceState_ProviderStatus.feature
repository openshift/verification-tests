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

And evaluation of `@result[:response].split("\n")` is stored in the :consoleOutput_array clipboard
#Evaluating Result for each line

When I repeat the following steps for each :consoleOutput in cb.consoleOutput_array:

   """

   And evaluation of `cb.consoleOutput.split(":")[1].split("]")[0]` is stored in the :providerStatus clipboard
   And evaluation of `cb.consoleOutput.split("]")[1].split("/\t")[1].split("/")[0]` is stored in the :instanceStatus clipboard

   Then the expression should be true> cb.providerStatus == 'running'

   """

Then the step should succeed

