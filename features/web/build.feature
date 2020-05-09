Feature: build related feature on web console
  # @author xxia@redhat.com
  # @case_id OCP-12494
  Scenario: Check build trigger info when the trigger is ImageChange on web
    Given I have a project
    When I run the :create client command with:
      | f    | <%= BushSlicer::HOME %>/testdata/build/tc528954/bc_imagechange.yaml |
    Then the step should succeed
    Given the "ruby-ex-1" build was created within 120 seconds
    When I perform the :check_build_trigger web console action with:
      | project_name      | <%= project.name %> |
      | bc_and_build_name | ruby-ex/ruby-ex-1   |
      | trigger_info      | Image change for ruby-22-centos7:latest |
    Then the step should succeed

