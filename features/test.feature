Feature: deployment/dc related features via web

  # @author hasha@redhat.com
  # @case_id OCP-19558
  Scenario: Check deployment page
    Given the master version >= "3.11"
    Given I waits for the "kibana" consoleexternalloglinks.console.openshift.io to appear 
