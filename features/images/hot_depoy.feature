Feature: hotdeploy.feature

  # @author wzheng@redhat.com
  @smoke
  Scenario Outline: Enable hot deploy for perl which is created from imagestream via oc new-app
    Given I have a project
    When I create a new application with:
      | app_repo     | <app_repo>     |
      | image_stream | <image_stream> |
      | env          | <env>          |
      | context_dir  | <context_dir>  |
      | name         | <buildcfg>     |
    Then the step should succeed
    And the "<buildcfg>-1" build was created
    And the "<buildcfg>-1" build completed
    Given I wait for the "<buildcfg>" service to become ready up to 300 seconds
    And I get the service pods
    When I execute on the pod:
      | sed | -i | <parameter> | <file_name> |
    Then the step should succeed
    When I expose the "<buildcfg>" service
    Then I wait for a web server to become available via the "<buildcfg>" route
    And the output should contain "hotdeploy_test"

    Examples:
      | app_repo | image_stream | env | buildcfg | parameter |  file_name | context_dir |
      | https://github.com/sclorg/s2i-perl-container.git | openshift/perl:5.20 | PERL_APACHE2_RELOAD=true | sti-perl | s/fine/hotdeploy_test/g |index.pl | 5.20/test/sample-test-app/ | # @case_id OCP-12142
      | https://github.com/sclorg/s2i-perl-container.git | openshift/perl:5.16 | PERL_APACHE2_RELOAD=true | sti-perl | s/fine/hotdeploy_test/g |index.pl | 5.16/test/sample-test-app/ | # @case_id OCP-11921
      | https://github.com/sclorg/s2i-perl-container.git | openshift/perl:5.24 | PERL_APACHE2_RELOAD=true | sti-perl | s/fine/hotdeploy_test/g |index.pl | 5.24/test/sample-test-app/ | # @case_id OCP-12175

