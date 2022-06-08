Feature: test git steps

  Scenario: git test
    And I git clone the repo "https://github.com/openshift/ruby-hello-world"
    And I git clone the repo "https://github.com/openshift/ruby-hello-world" to "dummy"
    And I get the latest git commit id from repo "https://github.com/openshift/ruby-hello-world"
    And I get the latest git commit id from repo "ruby-hello-world"
    And I get the latest git commit id from repo "dummy"
    And evaluation of `cb.git_commit_id` is stored in the :old_commit clipboard
    Given a "dummy/testfile" file is created with the following lines:
    """
    test
    """
    And I commit all changes in repo "dummy" with message "test"
    And I get the latest git commit id from repo "dummy"
    And evaluation of `cb.git_commit_id` is stored in the :new_commit clipboard
    Then the expression should be true> cb.new_commit != cb.old_commit
