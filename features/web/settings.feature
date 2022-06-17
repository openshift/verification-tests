Feature: check settings page on web console

  # @author yapei@redhat.com
  # @case_id OCP-12631
  @admin
  Scenario: OCP-12631 create project limit and quota, check settings on web console
    Given I have a project
    # create limit and quota via CLI
    Given I use the "<%= project.name %>" project
    And I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/quota.yaml |
      | n | <%= project.name %> |
    And I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/limits.yaml |
      | n | <%= project.name %> |
    Then the step should succeed

    # check quota and limit via CLI
    When I run the :describe client command with:
      | resource | quota |
      | name     | quota |
    Then the output should match:
      | cpu\\s+0\\s+1 |
      | memory\\s+0\\s+750Mi |
      | pods\\s+0\\s+10 |
      | replicationcontrollers\\s+0\\s+10 |
      | resourcequotas\\s+1\\s+1 |
      | services\\s+0\\s+10 |

    When I run the :describe client command with:
      | resource | limits |
      | name     | limits |
    Then the output should match:
      | Pod\\s+cpu\\s+10m\\s+500m\\s+ |
      | Pod\\s+memory\\s+5Mi\\s+750Mi\\s+ |
      | Container\\s+memory\\s+5Mi\\s+750Mi\\s+100Mi\\s+100Mi |
      | Container\\s+cpu\\s+10m\\s+500m\\s+100m\\s+100m |

    # check setting page layout
    And I perform the :check_settings_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed

    # check quota - cpu
    When I perform the :check_used_value web console action with:
      | resource_type | CPU     |
      | used_value    | 0 cores |
    Then the step should succeed
    When I perform the :check_max_value web console action with:
      | resource_type | CPU    |
      | max_value     | 1 core |
    Then the step should succeed
    # check quota - memory
    When I perform the :check_used_value web console action with:
      | resource_type | Memory |
      | used_value    | 0      |
    Then the step should succeed
    When I perform the :check_max_value web console action with:
      | resource_type | Memory  |
      | max_value     | 750 MiB |
    Then the step should succeed
    # check quota - pods
    When I perform the :check_used_value web console action with:
      | resource_type | Pods |
      | used_value    | 0    |
    Then the step should succeed
    When I perform the :check_max_value web console action with:
      | resource_type | Pods |
      | max_value     | 10   |
    Then the step should succeed
    # check quota - replicationcontrollers
    When I perform the :check_used_value web console action with:
      | resource_type | Replication Controllers |
      | used_value    | 0    |
    Then the step should succeed
    When I perform the :check_max_value web console action with:
      | resource_type | Replication Controllers |
      | max_value     | 10   |
    Then the step should succeed
    # check quota - services
    When I perform the :check_used_value web console action with:
      | resource_type | Services |
      | used_value    | 0    |
    Then the step should succeed
    When I perform the :check_max_value web console action with:
      | resource_type | Services |
      | max_value     | 10    |
    Then the step should succeed

    # check resource limits - Pod cpu
    When I perform the :check_min_limit_value web console action with:
      | resource_type | Pod CPU |
      | min_limit     | 10 millicores |
    Then the step should succeed
    When I perform the :check_max_limit_value web console action with:
      | resource_type | Pod CPU |
      | max_limit     | 500 millicores |
    Then the step should succeed
    # check resource limits - Pod memory
    When I perform the :check_min_limit_value web console action with:
      | resource_type | Pod Memory |
      | min_limit     | 5 MiB |
    Then the step should succeed
    When I perform the :check_max_limit_value web console action with:
      | resource_type | Pod Memory |
      | max_limit     | 750 MiB |
    Then the step should succeed
    # check resource limits - Container cpu
    When I perform the :check_min_limit_value web console action with:
      | resource_type | Container CPU |
      | min_limit     | 10 millicores |
    Then the step should succeed
    When I perform the :check_max_limit_value web console action with:
      | resource_type | Container CPU |
      | max_limit     | 500 millicores |
    Then the step should succeed
    When I perform the :check_default_request web console action with:
      | resource_type   | Container CPU  |
      | default_request | 100 millicores |
    Then the step should succeed
    When I perform the :check_default_limit web console action with:
      | resource_type   | Container CPU  |
      | default_limit   | 100 millicores |
    Then the step should succeed
    # check resource limits - Container memory
    When I perform the :check_min_limit_value web console action with:
      | resource_type | Container Memory |
      | min_limit     | 5 MiB |
    Then the step should succeed
    When I perform the :check_max_limit_value web console action with:
      | resource_type | Container Memory |
      | max_limit     | 750 MiB |
    Then the step should succeed
    When I perform the :check_default_request web console action with:
      | resource_type   | Container Memory |
      | default_request | 100 MiB          |
    Then the step should succeed
    When I perform the :check_default_limit web console action with:
      | resource_type   | Container Memory |
      | default_limit   | 100 MiB          |
    Then the step should succeed

  # @author xxing@redhat.com
  # @case_id OCP-10351
  Scenario: OCP-10351 Check Openshift Master and Kubernetes Master version on About page
    Given the master version >= "3.3"
    When I run the :version client command
    Then the step should succeed
    Given evaluation of `@result[:props][:openshift_server_version]` is stored in the :master1 clipboard
    And evaluation of `@result[:props][:kubernetes_server_version]` is stored in the :kube1 clipboard
    When I run the :goto_about_page web console action
    Then the step should succeed
    When I get the visible text on web html page
    And evaluation of `@result[:response].scan(/^OpenShift Master:\nv(.+)/)[0][0].split(' ')[0]` is stored in the :master2 clipboard
    And evaluation of `@result[:response].scan(/^Kubernetes Master:\nv(.+)/)[0][0]` is stored in the :kube2 clipboard
    Then the expression should be true> cb.master1 == cb.master2
    Then the expression should be true> cb.kube1 == cb.kube2
    When I perform the :check_web_console_version web console action with:
      | web_console_version | <%= cb.master1 %> |
    Then the step should succeed

  # @author hasha@redhat.com
  # @case_id OCP-16826
  Scenario: OCP-16826 User could set console home page
    Given the master version >= "3.9"

    # not able to set homepage as project overview when user has no project
    When I perform the :set_home_page web console action with:
      | prefered_homepage | project-overview |
    Then the step should fail
    When I run the :click_cancel_button web console action
    Then the step should succeed

    # set homepage to project overview when only one project
    Given I create a new project
    Then evaluation of `project.name` is stored in the :project1 clipboard
    When I access the "/console" path in the web console
    When I perform the :set_home_page web console action with:
      | prefered_homepage | project-overview |
    Then the step should succeed
    When I access the "/console" path in the web console
    When I perform the :check_page_contain_text web console action with:
      | text | Get started with your project. |
    Then the step should succeed

    # set homepage as one project overview when user has more than one project
    Given I create a new project
    Then evaluation of `project.name` is stored in the :project2 clipboard
    When I access the "/console" path in the web console
    When I perform the :set_home_page web console action with:
      | prefered_homepage | project-overview   |
      | project_name      | <%= cb.project2 %> |
    Then the step should succeed
    When I access the "/console" path in the web console
    When I perform the :check_page_contain_text web console action with:
      | text | <%= cb.project2 %> |
    Then the step should succeed

    # should give warning when visiting /console after project deleted
    When I delete the project
    When I access the "/console" path in the web console
    When I perform the :check_page_contain_text web console action with:
      | text | no longer exists or you do not have access to it.|
    Then the step should succeed

    # set home page back to 1st project overview, add view role to 2nd user, check 2nd user could see previous home page setting
    When I run the :click_set_homepage web console action
    Then the step should succeed
    When I perform the :set_homepage_in_modal web console action with:
      | prefered_homepage | project-overview |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role      | view                               |
      | user_name | <%= user(1,switch: false).name %>  |
      | n         | <%= cb.project1 %>                 |
    Then the step should succeed
    Given I logout via web console
    Given the second user is using same web console browser as first
    Given I switch to the second user
    Given I login via web console
    When I perform the :check_page_contain_text web action with:
      | text | <%= cb.project1 %> |
    Then the step should succeed

    # remove view role form 2nd user and visit /console, not able to view
    Given I switch to the first user
    When I run the :policy_remove_role_from_user client command with:
      | role      | view                               |
      | user_name | <%= user(1,switch: false).name %>  |
      | n         |  <%= cb.project1 %>                |
    Then the step should succeed
    When I access the "/console" path in the web console
    When I perform the :check_page_contain_text web console action with:
      | text | no longer exists or you do not have access to it.|
    Then the step should succeed

