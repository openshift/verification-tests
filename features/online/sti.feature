Feature: ONLY ONLINE STI related scripts in this file

  # @author etrott@redhat.com
  Scenario Outline: Private Repository can be used to providing dependency caching for STI builds
    Given I have a project
    Given I perform the :create_app_from_image web console action with:
      | project_name    | <%= project.name %>                               |
      | image_name      | <image>                                           |
      | image_tag       | <image_tag>                                       |
      | namespace       | openshift                                         |
      | app_name        | sti-sample                                        |
      | try_sample_repo | true                                              |
      | bc_env_key      | <env_name>                                        |
      | bc_env_value    | https://mirror.openshift.com/mirror/non-existing/ |
    Then the step should succeed
    When I perform the :wait_latest_build_to_status web console action with:
      | project_name | <%= project.name %> |
      | bc_name      | sti-sample          |
      | build_status | failed              |
    Then the step should succeed
    When I perform the :check_build_log_tab web console action with:
      | project_name      | <%= project.name %>     |
      | bc_and_build_name | sti-sample/sti-sample-1 |
      | build_status_name | Failed                  |
    Then the step should succeed
    When I perform the :check_build_log_content web console action with:
      | build_log_context | <error_message> https://mirror.openshift.com/mirror/non-existing/ |
    Then the step should succeed
    Given I perform the :change_env_vars_on_buildconfig_edit_page web console action with:
      | project_name      | <%= project.name %> |
      | bc_name           | sti-sample          |
      | env_variable_name | <env_name>          |
      | new_env_value     | <env_value>         |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I click the following "button" element:
      | text  | Start Build |
      | class | btn-default |
    Then the step should succeed
    When I run the :check_build_has_started_message web console action
    Then the step should succeed
    When I perform the :wait_latest_build_to_status web console action with:
      | project_name | <%= project.name %> |
      | bc_name      | sti-sample          |
      | build_status | complete            |
    Then the step should succeed
    When I perform the :check_build_log_tab web console action with:
      | project_name      | <%= project.name %>     |
      | bc_and_build_name | sti-sample/sti-sample-2 |
      | build_status_name | Complete                |
    Then the step should succeed

    # @case_id OCP-10089
    Examples: Python
      | case_id   | image  | image_tag | env_name      | env_value                                              | error_message               |
      | OCP-10089 | python | 2.7       | PIP_INDEX_URL | https://mirror.openshift.com/mirror/python/web/simple/ | Cannot fetch index base URL |
      | OCP-10089 | python | 3.3       | PIP_INDEX_URL | https://mirror.openshift.com/mirror/python/web/simple/ | Cannot fetch index base URL |
      | OCP-10089 | python | 3.4       | PIP_INDEX_URL | https://mirror.openshift.com/mirror/python/web/simple/ | Cannot fetch index base URL |
      | OCP-10089 | python | 3.5       | PIP_INDEX_URL | https://mirror.openshift.com/mirror/python/web/simple/ | Cannot fetch index base URL |

    # @case_id OCP-10088
    Examples: Ruby
      | case_id | image | image_tag | env_name       | env_value                    | error_message              |
      # ruby 2.0 has no environment variable for mirror url.
      | OCP-10088 | ruby | 2.2 | RUBYGEM_MIRROR | https://gems.ruby-china.com/ | Could not fetch specs from |
      | OCP-10088 | ruby | 2.3 | RUBYGEM_MIRROR | https://gems.ruby-china.com/ | Could not fetch specs from |

    # @case_id OCP-10087
    Examples: Perl
       | case_id   | image | image_tag | env_name    | env_value                                      | error_message |
       | OCP-10087 | perl  | 5.16      | CPAN_MIRROR | https://mirror.openshift.com/mirror/perl/CPAN/ | Fetching      |
       | OCP-10087 | perl  | 5.20      | CPAN_MIRROR | https://mirror.openshift.com/mirror/perl/CPAN/ | Fetching      |
       | OCP-10087 | perl  | 5.24      | CPAN_MIRROR | https://mirror.openshift.com/mirror/perl/CPAN/ | Fetching      |

