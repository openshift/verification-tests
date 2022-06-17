Feature: scenarios related to catalog page

  # @author chali@redhat.com
  # @case_id OCP-10989
  Scenario: OCP-10989 Check the browse catalog tab on "Add to Project" page
    Given the master version <= "3.6"
    Given I create a new project
    When I perform the :goto_overview_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I run the :click_add_to_project web console action
    Then the step should succeed
    # Filter by name or description on the "Browse Catalog" page
    # Filter by one keyword
    When I perform the :filter_by_keywords web console action with:
      | keyword | ruby |
    Then the step should succeed
    When I perform the :check_all_resources_tags_contain web console action with:
      | tag_name | ruby |
    Then the step should succeed
    When I run the :clear_keyword_filters web console action
    Then the step should succeed
    # Filter by partial keyword
    When I perform the :filter_by_keywords web console action with:
      | keyword | mongo |
    Then the step should succeed
    When I perform the :check_all_resources_tags_contain web console action with:
      | tag_name | mongo |
    Then the step should succeed
    When I run the :clear_keyword_filters web console action
    Then the step should succeed
    # Filter by multipul keyword
    When I perform the :filter_by_keywords web console action with:
      | keyword | node mongo |
    Then the step should succeed
    When I perform the :check_all_resources_tags_contain web console action with:
      | tag_name | node |
    Then the step should succeed
    When I perform the :check_all_resources_tags_contain web console action with:
      | tag_name | mongo |
    Then the step should succeed
    When I run the :clear_keyword_filters web console action
    Then the step should succeed
    # Filter by none-exist keyword
    When I perform the :filter_by_keywords web console action with:
      | keyword | hello |
    Then the step should succeed
    When I run the :check_all_content_is_hidden web console action
    Then the step should succeed
    When I run the :click_clear_filter_link web console action
    Then the step should succeed
    # Filter by invalid keyword
    When I perform the :filter_by_keywords web console action with:
      | keyword | $#@ |
    Then the step should succeed
    When I run the :check_all_content_is_hidden web console action
    Then the step should succeed
    When I run the :click_clear_filter_link web console action
    Then the step should succeed
    When I run the :check_all_categories_in_language_catalog web console action
    Then the step should succeed
    # check the ruby page
    When I perform the :select_category_in_catalog web console action with:
      | category | Ruby |
    Then the step should succeed
    # Filter by name or description on the "ruby" page
    # Filter by one keyword
    When I perform the :filter_by_keywords web console action with:
      | keyword | ruby |
    Then the step should succeed
    When I perform the :check_all_resources_tags_contain web console action with:
      | tag_name | ruby |
    Then the step should succeed
    When I run the :clear_keyword_filters web console action
    Then the step should succeed
    # Filter by partial keyword
    When I perform the :filter_by_keywords web console action with:
      | keyword | ra |
    Then the step should succeed
    When I perform the :check_all_resources_tags_contain web console action with:
      | tag_name | ra |
    Then the step should succeed
    When I run the :clear_keyword_filters web console action
    Then the step should succeed
    # Filter by multipul keyword
    When I perform the :filter_by_keywords web console action with:
      | keyword | rail postgresql |
    Then the step should succeed
    When I perform the :check_all_resources_tags_contain web console action with:
      | tag_name | rail |
    Then the step should succeed
    When I perform the :check_all_resources_tags_contain web console action with:
      | tag_name | postgresql |
    Then the step should succeed
    When I run the :clear_keyword_filters web console action
    Then the step should succeed
    # Filter by none-exist keyword
    When I perform the :filter_by_keywords web console action with:
      | keyword | hello |
    Then the step should succeed
    When I run the :check_all_content_is_hidden web console action
    Then the step should succeed
    When I run the :click_clear_filter_link web console action
    Then the step should succeed
    # Filter by invalid keyword
    When I perform the :filter_by_keywords web console action with:
      | keyword | $#@ |
    Then the step should succeed
    When I run the :check_all_content_is_hidden web console action
    Then the step should succeed
    When I run the :click_clear_filter_link web console action
    Then the step should succeed
    When I run the :click_add_to_project web console action
    Then the step should succeed
    When I perform the :select_category_in_catalog web console action with:
      | category  | Data Stores         |
      | namespace | <%= project.name %> |
    Then the step should succeed
    When I perform the :filter_by_keywords web console action with:
      | keyword | mongo  |
    Then the step should succeed
    When I perform the :check_all_resources_tags_contain web console action with:
      | tag_name | mongo |
    Then the step should succeed
    When I download a file from "https://raw.githubusercontent.com/openshift/origin/master/examples/db-templates/mongodb-persistent-template.json"
    When I delete matching lines from "mongodb-persistent-template.json":
      | "tags": "database,mongodb", |
    Then the step should succeed
    And I replace lines in "mongodb-persistent-template.json":
      | "openshift.io/display-name": "MongoDB", | "openshift.io/display-name": "chali", |
    When I run the :create client command with:
      | f | mongodb-persistent-template.json |
    Then the step should succeed
    When I run the :click_add_to_project web console action
    Then the step should succeed
    When I run the :check_all_categories_in_technologies_catalog web console action
    Then the step should succeed
    When I perform the :select_category_in_catalog web console action with:
      | category  | Uncategorized       |
      | namespace | <%= project.name %> |
    Then the step should succeed
    When I perform the :filter_by_keywords web console action with:
      | keyword | chali  |
    Then the step should succeed
    When I perform the :check_all_resources_tags_contain web console action with:
      | tag_name | chali |
    Then the step should succeed

