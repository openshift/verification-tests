Feature: create index catalog
  # based on https://gitlab.cee.redhat.com/aosqe/aosqe-tools/-/blob/master/app_registry_tools/create_index_catalogsource.sh
  @admin
  @destructive
  Scenario: create index catalogsource
    Given I create "qe-app-registry" catalogsource for testing

