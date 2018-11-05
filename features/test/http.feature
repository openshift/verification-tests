Feature: Some raw HTTP fetures

  Scenario: test download
    When I open web server via the "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/shared_compressed_files/char_test.txt" url
    Then the step should succeed
    When I download a big file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/shared_compressed_files/char_test.tar.gz"
    Then the step should succeed
    When I download a big file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/shared_compressed_files/char_test.txt"
    Then the step should succeed

  Scenario: Concurrent Get
    When I perform 100 HTTP GET requests with concurrency 25 to: <%= env.web_console_url %>
    Then the step should succeed
