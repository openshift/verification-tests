Feature: secrets related scenarios

  # @author yinzhou@redhat.com
  # @case_id OCP-10725
  Scenario: OCP-10725 deployment hook volume inheritance --with secret volume
    Given I have a project
    When I run the :secrets client command with:
      | action | new        |
      | name   | my-secret  |
      | source | /etc/hosts |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/tc510612/hook-inheritance-secret-volume.json |
    Then the step should succeed
  ## mount should be correct to the pod, no-matter if the pod is completed or not, check the case checkpoint
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource  | pod  |
      | resource_name | hooks-1-hook-pre |
      |  o        | yaml |
    Then the output by order should match:
      | - mountPath: /opt1    |
      | name: secret          |
      | secretName: my-secret |
    """

  # @author xiuwang@redhat.com
  # @case_id OCP-12290
  Scenario: OCP-12290 Create new secrets for ssh authentication
    Given I have a project
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cases/508971/id_rsa"
    When I run the :oc_secrets_new_sshauth client command with:
      |secret_name    |testsecret |
      |ssh_privatekey |id_rsa     |
    Then the step should succeed
    When I run the :get client command with:
      |resource      |secrets    |
      |resource_name |testsecret |
      |o             |yaml       |
    Then the step should succeed
    And the output should contain:
      |ssh-privatekey:|
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cases/508970/ca.crt"
    When I run the :oc_secrets_new_sshauth client command with:
      |secret_name    |testsecret2 |
      |ssh_privatekey |id_rsa      |
      |cafile         |ca.crt      |
    Then the step should succeed
    When I run the :get client command with:
      |resource      |secrets     |
      |resource_name |testsecret2 |
      |o             |yaml        |
    Then the step should succeed
    And the output should contain:
      |ssh-privatekey:|
      |ca.crt:        |

  # @author qwang@redhat.com
  # @case_id OCP-12281
  @smoke
  Scenario: OCP-12281:Node Pods do not have access to each other's secrets in the same namespace
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483168/first-secret.json |
    And I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483168/second-secret.json |
    Then the step should succeed
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483168/first-secret-pod.yaml |
    And I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483168/second-secret-pod.yaml |
    Then the step should succeed
    Given the pod named "first-secret-pod" status becomes :running
    When I run the :exec client command with:
      | pod              | first-secret-pod            |
      | exec_command     | cat                         |
      | exec_command_arg | /etc/secret-volume/username |
    Then the output should contain:
      | first-username |
    When I run the :exec client command with:
      | pod              | first-secret-pod            |
      | exec_command     | cat                         |
      | exec_command_arg | /etc/secret-volume/password |
    Then the output should contain:
      | password-first |
    Given the pod named "second-secret-pod" status becomes :running
    When I run the :exec client command with:
      | pod              | second-secret-pod           |
      | exec_command     | cat                         |
      | exec_command_arg | /etc/secret-volume/username |
    Then the output should contain:
      | second-username |
    When I run the :exec client command with:
      | pod              | second-secret-pod           |
      | exec_command     | cat                         |
      | exec_command_arg | /etc/secret-volume/password |
    Then the output should contain:
      | password-second |

  # @author qwang@redhat.com
  # @case_id OCP-12310
  Scenario: OCP-12310 Pods do not have access to each other's secrets with the same secret name in different namespaces
    Given I have a project
    Given evaluation of `project.name` is stored in the :project0 clipboard
    When I run the :create client command with:
      | filename  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483169/secret1.json |
    And I run the :create client command with:
      | filename  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483169/secret-pod-1.yaml |
    Then the step should succeed
    And the pod named "secret-pod-1" status becomes :running
    When I create a new project
    Given evaluation of `project.name` is stored in the :project1 clipboard
    And I run the :create client command with:
      | filename  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483169/secret2.json |
    And I run the :create client command with:
      | filename  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483169/secret-pod-2.yaml |
    Then the step should succeed
    And the pod named "secret-pod-2" status becomes :running
    When I run the :exec client command with:
      | pod              | secret-pod-2                  |
      | exec_command     | cat                           |
      | exec_command_arg | /etc/secret-volume-2/password |
      | namespace        | <%= cb.project1 %>            |
    Then the output should contain:
      | password-second |
    When I use the "<%= cb.project0 %>" project
    When I run the :exec client command with:
      | pod              | secret-pod-1                  |
      | exec_command     | cat                           |
      | exec_command_arg | /etc/secret-volume-1/username |
      | namespace        | <%= cb.project0 %>            |
    Then the output should contain:
      | first-username |

  # @author cryan@redhat.com
  # @case_id OCP-10690
  Scenario: OCP-10690 Add an arbitrary list of secrets to custom builds
    Given I have a project
    Given an 8 characters random string of type :dns is stored into the :pass1 clipboard
    Given an 8 characters random string of type :dns is stored into the :pass2 clipboard
    Given project role "system:build-strategy-custom" is added to the "first" user
    Then the step should succeed
    When I run the :secrets client command with:
      | action   | new-basicauth   |
      | name     | secret1         |
      | username | testuser1       |
      | password | <%= cb.pass1 %> |
    Then the step should succeed
    When I run the :secrets client command with:
      | action   | new-basicauth   |
      | name     | secret2         |
      | username | testuser2       |
      | password | <%= cb.pass2 %> |
    Then the step should succeed
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc507415/application-template-custombuild.json |
    Then the step should succeed
    Given the pod named "ruby-sample-build-1-build" status becomes :running
    When I run the :get client command with:
      | resource      | buildconfig       |
      | resource_name | ruby-sample-build |
      | o             | json              |
    Then the step should succeed
    And the output should contain:
      | secret1 |
      | secret2 |
    When I run the :exec admin command with:
      | pod              | ruby-sample-build-1-build |
      | n                | <%= project.name %>       |
      | exec_command     | ls                        |
      | exec_command_arg | /tmp                      |
    Then the output should contain:
      | secret1 |
      | secret2 |
    When I run the :exec admin command with:
      | pod              | ruby-sample-build-1-build |
      | n                | <%= project.name %>       |
      | exec_command     | cat                       |
      | exec_command_arg | /tmp/secret1/username     |
    Then the output should contain "testuser1"
    When I run the :exec admin command with:
      | pod              | ruby-sample-build-1-build |
      | n                | <%= project.name %>       |
      | exec_command     | cat                       |
      | exec_command_arg | /tmp/secret1/password     |
    Then the output should contain "<%= cb.pass1 %>"
    When I run the :exec admin command with:
      | pod              | ruby-sample-build-1-build |
      | n                | <%= project.name %>       |
      | exec_command     | cat                       |
      | exec_command_arg | /tmp/secret2/username     |
    Then the output should contain "testuser2"
    When I run the :exec admin command with:
      | pod              | ruby-sample-build-1-build |
      | n                | <%= project.name %>       |
      | exec_command     | cat                       |
      | exec_command_arg | /tmp/secret2/password     |
    Then the output should contain "<%= cb.pass2 %>"

  # @author yantan@redhat.com
  Scenario Outline: Insert secret to builder container via oc new-build - source/docker build
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc519256/testsecret1.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc519256/testsecret2.json |
    Then the step should succeed
    When I run the :new_build client command with:
      | image_stream | ruby:2.2 |
      | app_repo | https://github.com/yanliao/build-secret.git |
      | strategy | <type> |
      | build_secret | <build_secret> |
      | build_secret | testsecret2 |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/tc519261/test.json |
    Then the step should succeed
    Given the "build-secret-1" build was created
    And the "build-secret-1" build completed
    Given the pod named "build-secret-1-hook-pre" becomes present
    Given the pod named "build-secret-1-hook-pre" status becomes :running
    When I run the :exec client command with:
      | pod | build-secret-1-hook-pre |
      | exec_command | <command> |
      | exec_command_arg | <path>/secret1 |
      | exec_command_arg | <path>/secret2 |
      | exec_command_arg | <path>/secret3 |
      | exec_command_arg | /opt/app-root/src/secret1 |
      | exec_command_arg | /opt/app-root/src/secret2 |
      | exec_command_arg | /opt/app-root/src/secret3 |
    Then the step should succeed
    And the expression should be true> <expression>

    Examples:
      | type   | build_secret         | path      | command | expression               |
      | source | testsecret1:/tmp     | /tmp      | cat     | @result[:response] == "" | # @case_id OCP-12061
      | docker | testsecret1:mysecret1| mysecret1 | ls      | true                     | # @case_id OCP-11947

  # @author xiuwang@redhat.com
  # @case_id OCP-10851
  Scenario: OCP-10851 Build from private repo with/without secret of token --persistent gitserver
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/gitserver/gitserver-persistent.yaml |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | pvc                                                                             |
      | resource_name | git                                                                             |
      | p             | {"metadata":{"annotations":{"volume.alpha.kubernetes.io/storage-class":"foo"}}} |
    Then the step should succeed
    And the "git" PVC becomes :bound within 300 seconds

    When I run the :run client command with:
      | name  | gitserver                  |
      | image | openshift/origin-gitserver |
      | env   | GIT_HOME=/var/lib/git      |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role          | edit    |
      | serviceaccount| git     |
      | serviceaccount| default |
    Then the step should succeed
    When I run the :set_volume client command with:
      | resource    | dc/gitserver |
      | type        | emptyDir     |
      | action      | --add        |
      | mount-path  | /var/lib/git |
      | name        | 528228pv     |
    Then the step should succeed
    And evaluation of `route("git", service("git")).dns(by: user)` is stored in the :git_route clipboard
    When I run the :set_env client command with:
      | resource | dc/git                |
      | e        | BUILD_STRATEGY=source |
    Then the step should succeed


    #Create app when push code to initial repo
    Given a pod becomes ready with labels:
      | deploymentconfig=git |
      | deployment=git-2     |
    And a pod becomes ready with labels:
      | run=gitserver|
      | deployment=gitserver-2|
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      |bash|
      |-c  |
      |sed -i '1,2d' /var/lib/gitconfig/.gitconfig|
    Then the step should succeed
    """
    When I execute on the pod:
      |bash|
      |-c  |
      |git config --global credential.http://<%= cb.git_route%>.helper '!f() { echo "username=<%= @user.name %>"; echo "password=<%= user.cached_tokens.first %>"; }; f'|
    Then the step should succeed
    When I execute on the pod:
      |bash|
      |-c  |
      |cd /tmp/ ;git clone https://github.com/openshift/ruby-hello-world.git|
    Then the step should succeed
    When I execute on the pod:
      |bash|
      |-c  |
      |cd /tmp/ruby-hello-world/;git remote add openshift http://<%= cb.git_route%>/ruby-hello-world.git|
    Then the step should succeed
    When I execute on the pod:
      |bash|
      |-c  |
      |cd /tmp/ruby-hello-world/;git push openshift master|
    Then the step should succeed
    And the output should contain:
      |buildconfig "ruby-hello-world" created|
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby-hello-world |
      | o | json |
    Then the output should contain "sourceStrategy"
    Then I run the :delete client command with:
      | object_type       | builds             |
      | object_name_or_id | ruby-hello-world-1 |
    Then the step should succeed

    #Disable anonymous cloning
    When I run the :set_env client command with:
      | resource | dc/git                    |
      | e        | ALLOW_ANON_GIT_PULL=false |
    Then the step should succeed
    When I run the :oc_secrets_new_basicauth client command with:
      |secret_name |mysecret                          |
      |password    |<%= user.cached_tokens.first %>|
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | buildconfig      |
      | resource_name | ruby-hello-world |
      | p | {"spec": {"source": {"sourceSecret": {"name": "mysecret"}}}} |
    Then the step should succeed

    #Trigger second build automaticlly with secret
    And a pod becomes ready with labels:
      | deploymentconfig=git |
      | deployment=git-3     |
    And a pod becomes ready with labels:
      | run=gitserver|
      | deployment=gitserver-2|
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      |bash|
      |-c  |
      |cd /tmp/ruby-hello-world/;touch testfile;git add .;git commit -amp;git push openshift master|
    """
    Then the step should succeed
    And the output should contain:
      |started on build configuration 'ruby-hello-world'|
    Given I get project builds
    Then the output should contain "ruby-hello-world-2"
    Given the "ruby-hello-world-2" build completes

  # @author chezhang@redhat.com
  # @case_id OCP-10814
  @smoke
  Scenario: OCP-10814:Node Consume the same Secrets as environment variables in multiple pods
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/secret.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret   |
      | name     | test-secret |
    Then the output should match:
      | data-1:\\s+9\\s+bytes  |
      | data-2:\\s+11\\s+bytes |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job-secret-env.yaml |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource | pods |
    Then the step should succeed
    And the output should contain 3 times:
      |  secret-env- |
    """
    Given status becomes :succeeded of exactly 3 pods labeled:
      | app=test |
    Then the step should succeed
    And I wait until job "secret-env" completes
    When I run the :logs client command with:
      | resource_name | <%= pod(-3).name %> |
    Then the step should succeed
    And the output should contain:
      | MY_SECRET_DATA_1=value-1 |
      | MY_SECRET_DATA_2=value-2 |
    When I run the :logs client command with:
      | resource_name | <%= pod(-2).name %> |
    Then the step should succeed
    And the output should contain:
      | MY_SECRET_DATA_1=value-1 |
      | MY_SECRET_DATA_2=value-2 |
    When I run the :logs client command with:
      | resource_name | <%= pod(-1).name %> |
    Then the step should succeed
    And the output should contain:
      | MY_SECRET_DATA_1=value-1 |
      | MY_SECRET_DATA_2=value-2 |

  # @author chezhang@redhat.com
  # @case_id OCP-11260
  @smoke
  Scenario: OCP-11260:Node Using Secrets as Environment Variables
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/secret.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret   |
      | name     | test-secret |
    Then the output should match:
      | data-1:\\s+9\\s+bytes  |
      | data-2:\\s+11\\s+bytes |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/secret-env-pod.yaml |
    Then the step should succeed
    And the pod named "secret-env-pod" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | secret-env-pod |
    Then the step should succeed
    And the output should contain:
      | MY_SECRET_DATA=value-1 |

  # @author xiuwang@redhat.com
  # @case_id OCP-12204
  Scenario: OCP-12204 Build from private repos with secret of multiple auth methods
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/gitserver/gitserver-persistent.yaml |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | pvc                                                                             |
      | resource_name | git                                                                             |
      | p             | {"metadata":{"annotations":{"volume.alpha.kubernetes.io/storage-class":"foo"}}} |
    Then the step should succeed
    And the "git" PVC becomes :bound within 300 seconds

    When I run the :run client command with:
      | name  | gitserver                  |
      | image | openshift/origin-gitserver |
      | env   | GIT_HOME=/var/lib/git      |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role          | edit    |
      | serviceaccount| git     |
      | serviceaccount| default |
    Then the step should succeed
    When I run the :set_volume client command with:
      | resource    | dc/gitserver |
      | type        | emptyDir     |
      | action      | --add        |
      | mount-path  | /var/lib/git |
      | name        | 508969pv     |
    Then the step should succeed
    And evaluation of `route("git", service("git")).dns(by: user)` is stored in the :git_route clipboard
    When I run the :set_env client command with:
      | resource | dc/git                |
      | e        | REQUIRE_SERVER_AUTH=  |
      | e        | REQUIRE_GIT_AUTH=openshift:redhat |
      | e        | BUILD_STRATEGY=source |
    Then the step should succeed

    #Create app when push code to initial repo
    Given a pod becomes ready with labels:
      | deploymentconfig=git |
      | deployment=git-2     |
    And a pod becomes ready with labels:
      | run=gitserver|
      | deployment=gitserver-2|
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      |bash|
      |-c  |
      |sed -i '1,2d' /var/lib/gitconfig/.gitconfig|
    Then the step should succeed
    """
    When I execute on the pod:
      |bash|
      |-c  |
      |git config --global credential.http://<%= cb.git_route%>.helper '!f() { echo "username=openshift"; echo "password=redhat"; }; f'|
    Then the step should succeed
    When I execute on the pod:
      |bash|
      |-c  |
      |cd /tmp/ ;git clone https://github.com/openshift/ruby-hello-world.git|
    Then the step should succeed
    When I execute on the pod:
      |bash|
      |-c  |
      |cd /tmp/ruby-hello-world/;git remote add openshift http://<%= cb.git_route%>/ruby-hello-world.git|
    Then the step should succeed
    When I execute on the pod:
      |bash|
      |-c  |
      |cd /tmp/ruby-hello-world/;git push openshift master|
    Then the step should succeed
    And the output should contain:
      |buildconfig "ruby-hello-world" created|
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby-hello-world |
      | o | json |
    Then the output should contain "sourceStrategy"
    Then I run the :delete client command with:
      | object_type       | builds             |
      | object_name_or_id | ruby-hello-world-1 |
    Then the step should succeed

    #Disable anonymous cloning
    When I run the :set_env client command with:
      | resource | dc/git                    |
      | e        | ALLOW_ANON_GIT_PULL=false |
    Then the step should succeed
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cases/508964/.gitconfig"
    When I run the :oc_secrets_new_basicauth client command with:
      |secret_name|mysecret  |
      |username   |openshift |
      |password   |redhat    |
      |gitconfig  |.gitconfig|
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | buildconfig      |
      | resource_name | ruby-hello-world |
      | p | {"spec": {"source": {"sourceSecret": {"name": "mysecret"}}}} |
    Then the step should succeed

    #Trigger second build automaticlly with secret which contain multiple pairs secrets
    And a pod becomes ready with labels:
      | deploymentconfig=git |
      | deployment=git-3     |
    And a pod becomes ready with labels:
      | run=gitserver|
      | deployment=gitserver-2|
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      |bash|
      |-c  |
      |cd /tmp/ruby-hello-world/;touch testfile;git add .;git commit -amp;git push openshift master|
    """
    Then the step should succeed
    And the output should contain:
      |started on build configuration 'ruby-hello-world'|
    Given I get project builds
    Then the output should contain "ruby-hello-world-2"
    Given the "ruby-hello-world-2" build completes

    #Trigger third build automaticlly with secret which only contain a pair correct secret
    When I run the :oc_secrets_new_basicauth client command with:
      |secret_name|mysecret1 |
      |username   |invaild   |
      |password   |invaild   |
      |gitconfig  |.gitconfig|
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | buildconfig      |
      | resource_name | ruby-hello-world |
      | p | {"spec": {"source": {"sourceSecret": {"name": "mysecret1"}}}} |
    Then the step should succeed
    And a pod becomes ready with labels:
      | run=gitserver|
      | deployment=gitserver-2|
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      |bash|
      |-c  |
      |cd /tmp/ruby-hello-world/;touch testfile1;git add .;git commit -amp;git push openshift master|
    """
    Then the step should succeed
    And the output should contain:
      |started on build configuration 'ruby-hello-world'|
    Given I get project builds
    Then the output should contain "ruby-hello-world-3"
    Given the "ruby-hello-world-3" build completes

  # @author qwang@redhat.com
  # @case_id OCP-11311
  @smoke
  Scenario: OCP-11311:Node Secret volume should update when secret is updated
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483169/secret1.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483169/secret-pod-1.yaml |
    Then the step should succeed
    Given the pod named "secret-pod-1" status becomes :running
    When I run the :exec client command with:
      | pod              | secret-pod-1                  |
      | exec_command     | cat                           |
      | exec_command_arg | /etc/secret-volume-1/username |
    Then the output should contain:
      | first-username |
    When I run the :patch client command with:
      | resource      | secret                                                   |
      | resource_name | secret-n                                                 |
      | p             | {"data":{"username":"Zmlyc3QtdXNlcm5hbWUtdXBkYXRlCg=="}} |
    Then the step should succeed
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :exec client command with:
      | pod              | secret-pod-1                  |
      | exec_command     | cat                           |
      | exec_command_arg | /etc/secret-volume-1/username |
    Then the output should contain:
      | first-username-update |
    """
    Then the step should succeed

  # @author qwang@redhat.com
  # @case_id OCP-10899
  Scenario: OCP-10899 Mapping specified secret volume should update when secret is updated
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483169/secret1.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/mapping-secret-volume-pod.yaml |
    Then the step should succeed
    Given the pod named "mapping-secret-volume-pod" status becomes :running
    When I execute on the pod:
      | cat | /etc/secret-volume/test-secrets |
    Then the step should succeed
    And the output should contain:
      | first-username |
    When I run the :patch client command with:
      | resource      | secret                                                   |
      | resource_name | secret-n                                                 |
      | p             | {"data":{"username":"Zmlyc3QtdXNlcm5hbWUtdXBkYXRlCg=="}} |
    Then the step should succeed
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat | /etc/secret-volume/test-secrets |
    Then the output should contain:
      | first-username-update |
    """
    Then the step should succeed

  # @author qwang@redhat.com
  # @case_id OCP-10569
  Scenario: OCP-10569 Allow specifying secret data using strings and images
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/secret-datastring-image.json |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret                  |
      | name     | secret-datastring-image |
    Then the output should match:
      | image:\\s+7059\\s+bytes |
      | password:\\s+5\\s+bytes |
      | username:\\s+5\\s+bytes |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/pod-secret-datastring-image-volume.yaml |
    Then the step should succeed
    Given the pod named "pod-secret-datastring-image-volume" status becomes :running
    When I execute on the pod:
      | cat | /etc/secret-volume/username |
    Then the step should succeed
    And the output should contain:
      | hello |
    When I run the :patch client command with:
      | resource      | secret                           |
      | resource_name | secret-datastring-image          |
      | p             | {"stringData":{"username":"foobar"}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret                  |
      | name     | secret-datastring-image |
    Then the output should match:
      | image:\\s+7059\\s+bytes |
      | password:\\s+5\\s+bytes |
      | username:\\s+6\\s+bytes |
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat | /etc/secret-volume/username |
    Then the output should contain:
      | foobar |
    """
    Then the step should succeed

  # @author xiuwang@redhat.com
  # @case_id OCP-10982
  Scenario: OCP-10982 oc new-app to gather git creds
    Given I have a project
    When I have an http-git service in the project
    And I run the :set_env client command with:
      | resource | dc/git                            |
      | e        | REQUIRE_SERVER_AUTH=              |
      | e        | REQUIRE_GIT_AUTH=openshift:redhat |
      | e        | BUILD_STRATEGY=source             |
      | e        | ALLOW_ANON_GIT_PULL=false         |
    Then the step should succeed
    When a pod becomes ready with labels:
      | deploymentconfig=git |
      | deployment=git-2     |
    And I execute on the pod:
      | bash                                                                                                    |
      | -c                                                                                                      |
      | cd /var/lib/git/ && git clone --bare https://github.com/openshift/ruby-hello-world ruby-hello-world.git |
    Then the step should succeed
    When I run the :new_app client command with:
      | app_repo | ruby~http://<%= cb.git_route %>/ruby-hello-world.git |
    Then the step should succeed
    When I run the :oc_secrets_new_basicauth client command with:
      | secret_name | mysecret  |
      | username    | openshift |
      | password    | redhat    |
    Then the step should succeed
    When I run the :secret_link client command with:
      | secret_name | mysecret  |
      | sa_name     | builder   |
    Then the step should succeed
    And I run the :set_build_secret client command with:
      | bc_name     | ruby-hello-world |
      | secret_name | mysecret         |
      | source      | true             |
    Then the step should succeed
    Given the "ruby-hello-world-1" build fails
    And I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-2" build completed
    When I run the :delete client command with:
      | all_no_dash ||
      | all         ||
    Then the step should succeed

    When I have an ssh-git service in the project
    And the "secret" file is created with the following lines:
      | <%= cb.ssh_private_key.to_pem %> |
    And I run the :oc_secrets_new_sshauth client command with:
      | ssh_privatekey | secret    |
      | secret_name    | sshsecret |
    Then the step should succeed
    When I execute on the pod:
      | bash                                                                                                         |
      | -c                                                                                                           |
      | cd /repos/ && rm -rf sample.git && git clone --bare https://github.com/openshift/ruby-hello-world sample.git |
    Then the step should succeed
    When I run the :new_app client command with:
      | app_repo |ruby~<%= cb.git_repo %>|
    Then the step should succeed
    When I run the :secret_link client command with:
      | secret_name | sshsecret |
      | sa_name     | builder   |
    Then the step should succeed
    And I run the :set_build_secret client command with:
      | secret_name | sshsecret |
      | bc_name     | sample    |
      | source      | true      |
    Then the step should succeed
    Given the "sample-1" build fails
    And I run the :start_build client command with:
      | buildconfig | sample |
    Then the step should succeed
    And the "sample-2" build completed

  # @author shiywang@redhat.com xiuwang@redhat.com
  # @case_id OCP-12838
  Scenario: OCP-12838 Use build source secret based on annotation on Secret --http
    Given I have a project
    When I have an http-git service in the project
    And I run the :set_env client command with:
      | resource | dc/git                            |
      | e        | REQUIRE_SERVER_AUTH=              |
      | e        | REQUIRE_GIT_AUTH=openshift:redhat |
      | e        | BUILD_STRATEGY=source             |
      | e        | ALLOW_ANON_GIT_PULL=false         |
    Then the step should succeed
    When a pod becomes ready with labels:
      | deploymentconfig=git |
      | deployment=git-2     |
    And I execute on the pod:
      | bash                                                                                                    |
      | -c                                                                                                      |
      | cd /var/lib/git/ && git clone --bare https://github.com/openshift/ruby-hello-world ruby-hello-world.git |
    Then the step should succeed
    When I run the :oc_secrets_new_basicauth client command with:
      | secret_name | mysecret  |
      | username    | openshift |
      | password    | redhat    |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | secret                                                                   |
      | resourcename | mysecret                                                                 |
      | keyval       | build.openshift.io/source-secret-match-uri-1=http://<%= cb.git_route%>/* |
    Then the step should succeed

    When I run the :new_app client command with:
      | app_repo | ruby~http://<%= cb.git_route %>/ruby-hello-world.git |
      | l        | app=newapp1                                          |
    Then the step should succeed
    When I get project buildconfig as YAML
    And the output should match:
      | sourceSecret   |
      | name: mysecret |
    Given the "ruby-hello-world-1" build completed
    When I run the :delete client command with:
      | all_no_dash |             |
      | l           | app=newapp1 |
    Then the step should succeed

    When I run the :new_build client command with:
      | app_repo | ruby~http://<%= cb.git_route %>/ruby-hello-world.git |
      | l        | app=newapp2                                          |
    Then the step should succeed
    When I get project buildconfig as YAML
    And the output should match:
      | sourceSecret   |
      | name: mysecret |
    Given the "ruby-hello-world-1" build completed
    When I run the :delete client command with:
      | all_no_dash |             |
      | l           | app=newapp2 |
    Then the step should succeed

    When I run the :oc_secrets_new_basicauth client command with:
      | secret_name | override  |
      | username    | openshift |
      | password    | redhat    |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | secret                                                                       |
      | resourcename | override                                                                     |
      | keyval       | build.openshift.io/source-secret-match-uri-1=http://<%= cb.git_route%>/ruby* |
    Then the step should succeed
    When I run the :new_app client command with:
      | app_repo | ruby~http://<%= cb.git_route %>/ruby-hello-world.git |
      | l        | app=newapp3                                          |
    Then the step should succeed
    #Multiple Secrets match the Git URI of a particular BuildConfig, the secret with the longest match will be took
    When I get project buildconfig as YAML
    And the output should match:
      | sourceSecret   |
      | name: override |
    And the output should not contain "mysecret"
    Given the "ruby-hello-world-1" build completed

    When I run the :delete client command with:
      | all_no_dash |             |
      | l           | app=newapp3 |
    Then the step should succeed
    When I run the :new_build client command with:
      | app_repo | ruby~http://<%= cb.git_route %>/ruby-hello-world.git |
    Then the step should succeed
    When I get project buildconfig as YAML
    And the output should match:
      | sourceSecret   |
      | name: override |
    And the output should not contain "mysecret"
    Given the "ruby-hello-world-1" build completed

