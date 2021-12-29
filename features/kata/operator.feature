Feature: kata operator related tests
  Background:
  Given valid cluster type for kata tests exists

  # @author valiev@redhat.com
  # @case_id OCP-41813
  @admin
  @destructive
  Scenario: kata operator successfully installed
    Given kata operator is installed successfully
