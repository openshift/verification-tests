Feature: filter on create page

  # @author yanpzhan@redhat.com
  # @case_id OCP-11077
  Scenario: OCP-11077 Filter resources by labels under Browse page
    Given I have a project
    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>                        |
      | image_name   | python                                     |
      | image_tag    | 3.4                                        |
      | namespace    | openshift                                  |
      | app_name     | python-sample                              |
      | source_url   | https://github.com/sclorg/django-ex.git |
      | label_key    | label1                                     |
      | label_value  | test1                                      |
    Then the step should succeed
    Given the "python-sample-1" build was created
    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>                        |
      | image_name   | nodejs                                     |
      | image_tag    | 0.10                                       |
      | namespace    | openshift                                  |
      | app_name     | nodejs-sample                              |
      | source_url   | https://github.com/sclorg/nodejs-ex.git |
      | label_key    | label2                                     |
      | label_value  | test2                                      |
    Then the step should succeed
    Given the "nodejs-sample-1" build was created

    #Filter on Browse->Builds page
    When I perform the :goto_builds_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed

    When I perform the :filter_resources web console action with:
      | label_key     | label1 |
      | label_value   | test1  |
      | filter_action | in ... |
    Then the step should succeed

    When I get the visible text on web html page
    Then the output should contain:
      | python-sample |
    And the output should not contain:
      | nodejs-sample |

    #Filter on Browse->Deployments page
    When I perform the :goto_deployments_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed
    Given I wait until the status of deployment "nodejs-sample" becomes :complete
    Given I wait until the status of deployment "python-sample" becomes :complete
    When I perform the :filter_resources web console action with:
      | label_key     | label1 |
      | label_value   | test1  |
      | filter_action | in ... |
    Then the step should succeed

    When I get the visible text on web html page
    Then the output should contain:
      | python-sample |
    And the output should not contain:
      | nodejs-sample |

    #Filter on Browse->Image Streams page
    When I perform the :goto_image_streams_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed

    When I perform the :filter_resources web console action with:
      | label_key     | label1 |
      | label_value   | test1  |
      | filter_action | in ... |
    Then the step should succeed

    When I get the visible text on web html page
    Then the output should contain:
      | python-sample |
    And the output should not contain:
      | nodejs-sample |

    #Filter on Browse->Pods page
    When I perform the :goto_pods_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed

    When I perform the :filter_resources web console action with:
      | label_key     | openshift.io/build.name |
      | label_value   | nodejs-sample-1 |
      | filter_action | in ... |
    Then the step should succeed

    When I perform the :check_pod_in_pods_table web console action with:
      | project_name | <%= project.name %>   |
      | pod_name     | nodejs-sample-1-build |
      | status       | Completed             |
    Then the step should succeed
    When I perform the :check_pod_in_pods_table_missing web console action with:
      | project_name | <%= project.name %>   |
      | pod_name     | python-sample-1-build |
      | status       | Completed             |
    Then the step should succeed

    #Filter on Browse->Routes page
    When I perform the :goto_routes_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed

    When I perform the :filter_resources web console action with:
      | label_key     | label1 |
      | label_value   | test1  |
      | filter_action | in ... |
    Then the step should succeed

    When I get the visible text on web html page
    Then the output should contain:
      | python-sample |
    And the output should not contain:
      | nodejs-sample |

    #Filter on Browse->Services page
    When I perform the :goto_services_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed

    When I perform the :filter_resources web console action with:
      | label_key     | label1 |
      | label_value   | test1  |
      | filter_action | in ... |
    Then the step should succeed

    When I get the visible text on web html page
    Then the output should contain:
      | python-sample |
    And the output should not contain:
      | nodejs-sample |

    #Filter with non-existing label
    When I perform the :filter_resources_with_non_existing_label web console action with:
      | label_key     | nolabel |
      | press_enter   | :enter  |
      | label_value   | novalue |
      | filter_action | in ...  |
    Then the step should succeed
    When I get the html of the web page
    Then the output should match:
      | The.*filter.*hiding all |

    #Clear one filter
    When I perform the :clear_one_filter web console action with:
      | filter_name | nolabel in (novalue) |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I get the html of the web page
    Then the output should contain:
      | python-sample |
    And the output should not match:
      | The.*filter.*hiding all |
    """

    When I perform the :filter_resources_with_non_existing_label web console action with:
      | label_key     | i*s#$$% |
      | press_enter   | :enter  |
      | label_value   | 1223$@@ |
      | filter_action | in ...  |
    Then the step should succeed
    When I get the html of the web page
    Then the output should match:
      | The.*filter.*hiding all |

    #Clear all filters
    When I run the :clear_all_filters web console action
    Then the step should succeed
    When I get the visible text on web html page
    Then the output should contain:
      | python-sample  |
      | nodejs-sample  |

     #Filter with other operator actions
    When I perform the :filter_resources web console action with:
      | label_key     | label1 |
      | label_value   | test1  |
      | filter_action | not in ... |
    Then the step should succeed

    When I get the visible text on web html page
    Then the output should contain:
      | nodejs-sample |
    And the output should not contain:
      | python-sample |

    When I run the :clear_all_filters web console action
    Then the step should succeed

    When I perform the :filter_resources_with_exists_option web console action with:
      | label_key     | label1 |
      | filter_action | exists |
    Then the step should succeed

    When I get the visible text on web html page
    Then the output should contain:
      | python-sample |
    And the output should not contain:
      | nodejs-sample |

  # @author yanpzhan@redhat.com
  # @case_id OCP-11698
  Scenario: OCP-11698 Display existing labels in label suggestion list according to different resources
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/python:latest                |
      | code         | https://github.com/sclorg/django-ex |
      | name         | python-sample                          |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | service       |
      | resource_name | python-sample |
    Then the step should succeed
    Given the "python-sample-1" build was created

    # Check suggested labels on overview page.
    When I perform the :check_suggested_label_on_overview_page web console action with:
      | project_name | <%= project.name%> |
      | label        | app                |
    Then the step should succeed

    # Check suggested labels on builds page.
    When I perform the :goto_builds_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed
    When I run the :click_filter_box web console action
    Then the step should succeed
    When I perform the :check_suggested_label web console action with:
      | label | app |
    Then the step should succeed

    # Check suggested labels on bc page.
    When I perform the :goto_one_buildconfig_page web console action with:
      | project_name | <%= project.name%> |
      | bc_name | python-sample |
    Then the step should succeed
    When I run the :click_filter_box web console action
    Then the step should succeed
    When I perform the :check_suggested_label web console action with:
      | label | app |
    Then the step should succeed
    When I perform the :check_suggested_label web console action with:
      | label | buildconfig |
    Then the step should succeed
    When I perform the :check_suggested_label web console action with:
      | label | openshift.io/build-config.name |
    Then the step should succeed

    # Check suggested labels on deployments page.
    When I perform the :goto_deployments_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed
    When I run the :click_filter_box web console action
    Then the step should succeed
    When I perform the :check_suggested_label web console action with:
      | label | app |
    Then the step should succeed

    # Check suggested labels on imagestreams page.
    When I perform the :goto_image_streams_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed
    When I run the :click_filter_box web console action
    Then the step should succeed
    When I perform the :check_suggested_label web console action with:
      | label | app |
    Then the step should succeed

    # Check suggested labels on pods page.
    When I perform the :goto_pods_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed
    When I run the :click_filter_box web console action
    Then the step should succeed
    When I perform the :check_suggested_label web console action with:
      | label | openshift.io/build.name |
    Then the step should succeed

    # Check suggested labels on routes page.
    When I perform the :goto_routes_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed
    When I run the :click_filter_box web console action
    Then the step should succeed
    When I perform the :check_suggested_label web console action with:
      | label | app |
    Then the step should succeed

    # Check suggested labels on services page.
    When I perform the :goto_services_page web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed
    When I run the :click_filter_box web console action
    Then the step should succeed
    When I perform the :check_suggested_label web console action with:
      | label | app |
    Then the step should succeed

