Feature: kata related features
  # @author pruan@redhat.com
  # @case_id OCP-36508
  @admin
  @destructive
  Scenario: kata container operator installation
    Given the master version >= "4.6"
    Given kata container has been installed successfully in the "kata-operator" project
    And I verify kata container runtime is installed into the a worker node

  # @author pruan@redhat.com
  # @case_id OCP-36509
  @admin
  @destructive
  Scenario: test delete kata installation
    Given I remove kata operator from the namespace


  Scenario: test install kata-webhook
    Given I have a project
    And evaluation of `project.name` is stored in the :test_project_name clipboard
    And I run oc create over ERB test file: kata/webhook/example-fedora.yaml
    And the pod named "example-fedora" becomes ready
    Then the expression should be true> pod.runtime_class_name == 'kata'

  # @author pruan@redhat.com
  # @case_id OCP-39344
  @admin
  @destructive
  Scenario: Operator can be installed through web console
    Given the master version >= "4.7"
    Given the kata-operator is installed using OLM GUI
    # Given there is a catalogsource for kata container
    # Given the first user is cluster-admin
    # And I run the :
    # And evaluation of `project('openshift-operators')` is stored in the :project clipboard
    # And evaluation of `cluster_version('version').version.split('-')[0].to_f` is stored in the :channel clipboard
    # When I open admin console in a browser
    # Then the step should succeed
    # When I perform the :goto_operator_subscription_page web action with:
    #   | package_name     | nfd                    |
    #   | catalog_name     | qe-app-registry        |
    #   | target_namespace | <%= cb.project.name %> |
    # Then the step should succeed
    # And I perform the :set_custom_channel_and_subscribe web action with:
    #   | update_channel    | <%= cb.channel %> |
    #   | install_mode      | OwnNamespace      |
    #   | approval_strategy | Automatic         |
    # Then the step should succeed


  # @author pruan@redhat.com
  # @case_id OCP-39499
  @admin
  @destructive
  Scenario: kata operator can be installed via CLI with OLM for OCP>=4.7
    Given the master version >= "4.7"
    Given the kata-operator is installed using OLM CLI
