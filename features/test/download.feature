Feature: download a file from web or relative path
  Scenario: download from web
    Given I have a project
    And I download a file from "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/quota/pvc-storage-class.json"
    When I run the :create client command with:
      | f | pvc-storage-class.json |
    Then the step should succeed

  Scenario: download from relative path
    Given I have a project
    And I download a file from "<%= BushSlicer::HOME %>/testdata/quota/pvc-storage-class.json"
    When I run the :create client command with:
      | f | pvc-storage-class.json |
    Then the step should succeed
