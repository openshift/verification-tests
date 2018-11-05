Feature: quickstarts.feature

  # @author cryan@redhat.com haowang@redhat.com
  Scenario Outline: quickstart test
    Given I have a project
    When I run the :new_app client command with:
      | template | <template> |
    Then the step should succeed
    And the "<buildcfg>-1" build was created
    And the "<buildcfg>-1" build completed
    And I wait for the "<buildcfg>" service to become ready up to 300 seconds
    Then I wait for a web server to become available via the "<buildcfg>" route
    Then the output should contain "<output>"

    Examples: OS Type
      | template                  | buildcfg                 | output  | podno |
      | django-psql-example       | django-psql-example      | Django  | 2     | # @case_id OCP-12609
      | dancer-mysql-example      | dancer-mysql-example     | Dancer  | 2     | # @case_id OCP-12606
      | cakephp-mysql-example     | cakephp-mysql-example    | CakePHP | 2     | # @case_id OCP-12541
      | nodejs-mongodb-example    | nodejs-mongodb-example   | Node.js | 2     | # @case_id OCP-9570
      | rails-postgresql-example  | rails-postgresql-example | Rails   | 2     | # @case_id OCP-12296
      | dotnet-example            | dotnet-example           | ASP.NET | 1     | # @case_id OCP-13749
      | openjdk18-web-basic-s2i   | openjdk-app          | Hello World | 1     | # @case_id OCP-17826

  # @author xiuwang@redhat.com
  @smoke
  Scenario Outline: quickstart with persistent volume test
    Given I have a project
    When I run the :new_app client command with:
      | template | <template> |
    When I run the :patch client command with:
      | resource      | pvc                                                                             |
      | resource_name | <pvc>                                                                           |
      | p             | {"metadata":{"annotations":{"volume.alpha.kubernetes.io/storage-class":"foo"}}} |
    Then the step should succeed
    And the "<pvc>" PVC becomes :bound within 300 seconds
    Then the step should succeed
    And the "<buildcfg>-1" build was created
    And the "<buildcfg>-1" build completed
    And I wait for the "<buildcfg>" service to become ready up to 300 seconds
    Then I wait for a web server to become available via the "<buildcfg>" route
    Then the output should contain "<output>"

    Examples: OS Type
      | template                 |pvc       | buildcfg               | output | podno |
      | django-psql-persistent   |postgresql| django-psql-persistent | Django | 2     | # @case_id OCP-12825
      | rails-pgsql-persistent   |postgresql| rails-pgsql-persistent | Rails  | 2     | # @case_id OCP-12822
      | cakephp-mysql-persistent |mysql     |cakephp-mysql-persistent| CakePHP| 2     | # @case_id OCP-12492
      | dancer-mysql-persistent  |database  |dancer-mysql-persistent | Dancer | 2     | # @case_id OCP-13658
      | nodejs-mongo-persistent  |mongodb   |nodejs-mongo-persistent | Node.js| 2     | # @case_id OCP-13574
      | dotnet-pgsql-persistent  |postgresql| musicstore             | ASP.NET| 2     | # @case_id OCP-13751

