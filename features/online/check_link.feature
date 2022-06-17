Feature: Check links in Openshift

  # @author yasun@redhat.com
  # @case_id OCP-9873
  Scenario: OCP-9873 Check the CLI download links on web page
    When I run the :version client command
    Then the step should succeed
    And evaluation of `@result[:props][:openshift_server_version]` is stored in the :server_version clipboard

    # check the download links on command line page
    When I perform the :check_download_cli_doc_link_in_cli_page_online web console action with:
      | platform     | Linux (64 bits)                           |
      | download_url | <%= cb.server_version %>/linux/oc.tar.gz  |
    Then the step should succeed
    When I perform the :check_download_cli_doc_link_in_cli_page_online web console action with:
      | platform     | Mac OS X                                  |
      | download_url | <%= cb.server_version %>/macosx/oc.tar.gz |
    Then the step should succeed
    When I perform the :check_download_cli_doc_link_in_cli_page_online web console action with:
      | platform     | Windows                                   |
      | download_url | <%= cb.server_version %>/windows/oc.zip   |
    Then the step should succeed

    # check the effectiveness of the download links
    # store the link in clipboard
    When I get the "href" attribute of the "a" web element:
      | text  | Linux (64 bits) |
    And evaluation of `@result[:response]` is stored in the :linux clipboard
    When I get the "href" attribute of the "a" web element:
      | text  | Mac OS X        |
    And evaluation of `@result[:response]` is stored in the :macosx clipboard
    When I get the "href" attribute of the "a" web element:
      | text  | Windows         |
    And evaluation of `@result[:response]` is stored in the :windows clipboard

    Given I have a project
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl | -I | <%= cb.linux %>   |
    Then the output should match "HTTP/.* 200 OK"
    When I execute on the pod:
      | curl | -I | <%= cb.macosx %>  |
    Then the output should match "HTTP/.* 200 OK"
    When I execute on the pod:
      | curl | -I | <%= cb.windows %> |
    Then the output should match "HTTP/.* 200 OK"

