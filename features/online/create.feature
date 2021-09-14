Feature: ONLY ONLINE Create related feature's scripts in this file

  # @author bingli@redhat.com
  @inactive
  Scenario Outline: Maven repository can be used to providing dependency caching for xPaas templates
    Given I have a project
    When I run the :new_app client command with:
      | template | <template>                                       |
      | param    | <env_name>=https://repo1.maven.org/non-existing/ |
      | param    | <parameter_name>=myapp                           |
    Then the step should succeed
    Given the "myapp-1" build was created
    And the "myapp-1" build failed
    When I run the :logs client command with:
      | resource_name | build/myapp-1 |
    Then the output should contain:
      | https://repo1.maven.org/non-existing/ |
    # @case_id OCP-10106
    Examples: MAVEN
      | template                                | parameter_name   | env_name         |
      | eap71-amq-persistent-s2i                | APPLICATION_NAME | MAVEN_MIRROR_URL |
      | eap71-basic-s2i                         | APPLICATION_NAME | MAVEN_MIRROR_URL |
      | eap71-https-s2i                         | APPLICATION_NAME | MAVEN_MIRROR_URL |
      | eap71-postgresql-persistent-s2i         | APPLICATION_NAME | MAVEN_MIRROR_URL |
      | jws31-tomcat7-https-s2i                 | APPLICATION_NAME | MAVEN_MIRROR_URL |
      | jws31-tomcat8-https-s2i                 | APPLICATION_NAME | MAVEN_MIRROR_URL |
      | jws31-tomcat8-mongodb-persistent-s2i    | APPLICATION_NAME | MAVEN_MIRROR_URL |
      | jws31-tomcat8-mysql-persistent-s2i      | APPLICATION_NAME | MAVEN_MIRROR_URL |
      | jws31-tomcat8-postgresql-persistent-s2i | APPLICATION_NAME | MAVEN_MIRROR_URL |
    # @case_id OCP-12688
    Examples: CPAN
      | template                | parameter_name | env_name    |
      | dancer-mysql-persistent | NAME           | CPAN_MIRROR |
    # @case_id OCP-12689
    Examples: RUBYGEM
      | template               | parameter_name | env_name       |
      | rails-pgsql-persistent | NAME           | RUBYGEM_MIRROR |

  # @author etrott@redhat.com
  # @case_id OCP-10270
  Scenario: Create Laravel application with a MySQL database using default template laravel-mysql-example
    Given I have a project
    Then I run the :new_app client command with:
      | template | laravel-mysql-persistent |
    Then the step should succeed
    Then the "laravel-mysql-persistent-1" build was created
    And the "laravel-mysql-persistent-1" build completed
    And a pod becomes ready with labels:
      | deployment=laravel-mysql-persistent-1 |
    And I wait for the "laravel-mysql-persistent" service to become ready
    Then I wait for a web server to become available via the "laravel-mysql-persistent" route

  # @author yuwan@redhat.com
  # @case_id OCP-12687
  Scenario: PyPi index can be used to providing dependencies for django-psql-example template
    Given I have a project
    When I run the :new_app client command with:
      | template | django-psql-persistent                                               |
      | param    | PIP_INDEX_URL=https://mirror.openshift.com/mirror/python/web/simple/ |
      | param    | NAME=myapp                                                           |
    Then the step should succeed
    Given the "myapp-1" build was created
    And the "myapp-1" build completed
    When I run the :build_logs client command with:
      | build_name | myapp-1 |
    Then the output should match:
      | Downloading\s*https://mirror.openshift.com/mirror/python/web/.* |
    When I run the :patch client command with:
      | resource      | bc                                                                                                                                                        |
      | resource_name | myapp                                                                                                                                                     |
      | p             | {"spec":{"strategy":{"sourceStrategy":{"env":[{"name":"PIP_INDEX_URL","value":"https://mirror.openshift.com/mirror/python/web/simple/non-existing/"}]}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | myapp |
    Then the "myapp-2" build was created
    And the "myapp-2" build failed
    When I run the :build_logs client command with:
      | build_name | myapp-2 |
    Then the output should match:
      | Could not find a version that satisfies the requirement |

