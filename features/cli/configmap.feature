Feature: configMap

  # @author chezhang@redhat.com
  # @case_id OCP-10805
  @smoke
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Consume ConfigMap in environment variables
    Given I have a project
    Given I obtain test data file "configmap/configmap.yaml"
    When I run the :create client command with:
      | f | configmap.yaml |
      | n | <%= project.name %>                                                                   |
    Then the step should succeed
    When I run the :get client command with:
      | resource | configmap |
    Then the output should match:
      | NAME.*DATA        |
      | special-config.*2 |
    When I run the :describe client command with:
      | resource | configmap      |
      | name     | special-config |
    Then the output should match:
      | special.how  |
      | special.type |
    Given I obtain test data file "configmap/pod-configmap-env.yaml"
    When I run the :create client command with:
      | f | pod-configmap-env.yaml |
    Then the step should succeed
    And the pod named "dapi-test-pod" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | dapi-test-pod |
    Then the step should succeed
    And the output should contain:
      | SPECIAL_TYPE_KEY=charm |
      | SPECIAL_LEVEL_KEY=very |

  # @author chezhang@redhat.com
  # @case_id OCP-11255
  @smoke
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Consume ConfigMap via volume plugin
    Given I have a project
    Given I obtain test data file "configmap/configmap.yaml"
    When I run the :create client command with:
      | f | configmap.yaml |
      | n | <%= project.name %>                                                                   |
    Then the step should succeed
    When I run the :get client command with:
      | resource | configmap |
    Then the output should match:
      | NAME.*DATA        |
      | special-config.*2 |
    When I run the :describe client command with:
      | resource | configmap      |
      | name     | special-config |
    Then the output should match:
      | special.how  |
      | special.type |
    Given I obtain test data file "configmap/pod-configmap-volume1.yaml"
    When I run the :create client command with:
      | f | pod-configmap-volume1.yaml |
    Then the step should succeed
    And the pod named "dapi-test-pod-1" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | dapi-test-pod-1 |
    Then the step should succeed
    And the output should contain:
      | very |
    Given I obtain test data file "configmap/pod-configmap-volume2.yaml"
    When I run the :create client command with:
      | f | pod-configmap-volume2.yaml |
    Then the step should succeed
    And the pod named "dapi-test-pod-2" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | dapi-test-pod-2 |
    Then the step should succeed
    And the output should contain:
      | charm |

  # @author chezhang@redhat.com
  # @case_id OCP-11572
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Perform CRUD operations against a ConfigMap resource
    Given I have a project
    Given I obtain test data file "configmap/configmap-example.yaml"
    When I run the :create client command with:
      | f | configmap-example.yaml |
      | n | <%= project.name %>                                                                   |
    Then the step should succeed
    When I run the :get client command with:
      | resource | configmap |
    Then the output should match:
      | NAME.*DATA        |
      | example-config.*3 |
    When I run the :describe client command with:
      | resource | configmap      |
      | name     | example-config |
    Then the output should match:
      | example.property.file |
      | example.property.1    |
      | example.property.2    |
    When I run the :patch client command with:
      | resource | configmap |
      | resource_name | example-config |
      | p | {"data":{"example.property.1":"hello_configmap_update"}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | configmap      |
      | name     | example-config |
    Then the output should match:
      | example.property.file |
      | example.property.1    |
      | example.property.2    |
    When I run the :delete client command with:
      | object_type | configmap         |
      | object_name_or_id | example-config |
    Then the step should succeed
    And the output should match:
      | configmap "example-config" deleted |

  # @author chezhang@redhat.com
  # @case_id OCP-9882
  @smoke
  @inactive
  Scenario: Set command-line arguments with ConfigMap
    Given I have a project
    Given I obtain test data file "configmap/configmap.yaml"
    When I run the :create client command with:
      | f | configmap.yaml |
      | n | <%= project.name %>                                                                   |
    Then the step should succeed
    When I run the :get client command with:
      | resource | configmap |
    Then the output should match:
      | NAME.*DATA        |
      | special-config.*2 |
    When I run the :describe client command with:
      | resource | configmap      |
      | name     | special-config |
    Then the output should match:
      | special.how  |
      | special.type |
    Given I obtain test data file "configmap/pod-configmap-command.yaml"
    When I run the :create client command with:
      | f | pod-configmap-command.yaml |
    Then the step should succeed
    And the pod named "dapi-test-pod" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | dapi-test-pod |
    Then the step should succeed
    And the output should contain:
      | very charm |

  # @author chezhang@redhat.com
  # @case_id OCP-9884
  @inactive
  Scenario: Configuring redis using ConfigMap
    Given I have a project
    Given a "redis-config" file is created with the following lines:
    """
    maxmemory 2mb
    maxmemory-policy allkeys-lru
    """
    When I run the :create_configmap client command with:
      | name      | example-redis-config |
      | from_file | redis-config         |
    Then the step should succeed
    When I run the :describe client command with:
      | resource  | configmap            |
      | name      | example-redis-config |
    Then the output should match:
      | Name.*example-redis-config |
      | redis-config               |
    Given I obtain test data file "configmap/pod-configmap-redis.yaml"
    When I run the :create client command with:
      | f | pod-configmap-redis.yaml |
    Then the step should succeed
    Given the pod named "redis" becomes ready
    When I execute on the pod:
      | redis-cli | CONFIG | GET | maxmemory |
    Then the output should match:
      | maxmemory |
      | 2097152   |
    When I execute on the pod:
      | redis-cli | CONFIG | GET | maxmemory-policy |
    Then the output should match:
      | maxmemory-policy |
      | allkeys-lru      |

  # @author chezhang@redhat.com
  # @case_id OCP-9880
  @smoke
  @inactive
  Scenario: Create ConfigMap from file
    Given I have a project
    Given I create the "configmap-test" directory
    Given a "configmap-test/game.properties" file is created with the following lines:
    """
    enemies=aliens
    lives=3
    enemies.cheat=true
    enemies.cheat.level=noGoodRotten
    secret.code.passphrase=UUDDLRLRBABAS
    secret.code.allowed=true
    secret.code.lives=30
    """
    Given a "configmap-test/ui.properties" file is created with the following lines:
    """
    color.good=purple
    color.bad=yellow
    allow.textmode=true
    how.nice.to.look=fairlyNice
    """
    When I run the :create_configmap client command with:
      | name      | game-config-1                  |
      | from_file | configmap-test/game.properties |
    Then the step should succeed
    When I run the :describe client command with:
      | resource  | configmap     |
      | name      | game-config-1 |
    Then the output should match:
      | Name.*game-config-1 |
      | game.properties     |
    When I get project configmap named "game-config-1" as YAML
    Then the output by order should match:
      | game.properties: \|                  |
      | enemies=aliens                       |
      | lives=3                              |
      | enemies.cheat=true                   |
      | enemies.cheat.level=noGoodRotten     |
      | secret.code.passphrase=UUDDLRLRBABAS |
      | secret.code.allowed=true             |
      | secret.code.lives=30                 |
      | name: game-config-1                  |
    When I run the :create_configmap client command with:
      | name      | game-config-2                  |
      | from_file | configmap-test/game.properties |
      | from_file | configmap-test/ui.properties   |
    Then the step should succeed
    When I run the :describe client command with:
      | resource  | configmap     |
      | name      | game-config-2 |
    Then the output should match:
      | Name.*game-config-2 |
      | game.properties     |
      | ui.properties       |
    When I get project configmap named "game-config-2" as YAML
    Then the output by order should match:
      | game.properties: \|                  |
      | enemies=aliens                       |
      | lives=3                              |
      | enemies.cheat=true                   |
      | enemies.cheat.level=noGoodRotten     |
      | secret.code.passphrase=UUDDLRLRBABAS |
      | secret.code.allowed=true             |
      | secret.code.lives=30                 |
      | ui.properties: \|                    |
      | color.good=purple                    |
      | color.bad=yellow                     |
      | allow.textmode=true                  |
      | how.nice.to.look=fairlyNice          |
      | name: game-config-2                  |
    When I run the :create_configmap client command with:
      | name      | game-config-3                                   |
      | from_file | game-special-key=configmap-test/game.properties |
    Then the step should succeed
    When I get project configmap named "game-config-3" as YAML
    Then the output by order should match:
      | game-special-key: \|                 |
      | enemies=aliens                       |
      | lives=3                              |
      | enemies.cheat=true                   |
      | enemies.cheat.level=noGoodRotten     |
      | secret.code.passphrase=UUDDLRLRBABAS |
      | secret.code.allowed=true             |
      | secret.code.lives=30                 |
      | name: game-config-3                  |
    When I run the :delete client command with:
      | object_type       | configmap     |
      | object_name_or_id | game-config-1 |
      | object_name_or_id | game-config-2 |
      | object_name_or_id | game-config-3 |
    Then the step should succeed

  # @author chezhang@redhat.com
  # @case_id OCP-9881
  @inactive
  Scenario: Create ConfigMap from literal values
    Given I have a project
    When I run the :create_configmap client command with:
      | name         | special-config     |
      | from_literal | special.how=very   |
      | from_literal | special.type=charm |
    Then the step should succeed
    When I run the :describe client command with:
      | resource  | configmap      |
      | name      | special-config |
    Then the output should match:
      | Name.*special-config |
      | special.how          |
      | special.type         |
    When I get project configmap named "special-config" as YAML
    Then the output by order should match:
      | special.how: very    |
      | special.type: charm  |
      | kind: ConfigMap      |
      | name: special-config |

  # @author chezhang@redhat.com
  # @case_id OCP-9879
  @inactive
  Scenario: Create ConfigMap from directories
    Given I have a project
    Given I create the "configmap-test" directory
    Given a "configmap-test/game.properties" file is created with the following lines:
    """
    enemies=aliens
    lives=3
    enemies.cheat=true
    enemies.cheat.level=noGoodRotten
    secret.code.passphrase=UUDDLRLRBABAS
    secret.code.allowed=true
    secret.code.lives=30
    """
    Given a "configmap-test/ui.properties" file is created with the following lines:
    """
    color.good=purple
    color.bad=yellow
    allow.textmode=true
    how.nice.to.look=fairlyNice
    """
    When I run the :create_configmap client command with:
      | name      | game-config    |
      | from_file | configmap-test |
    Then the step should succeed
    When I run the :describe client command with:
      | resource  | configmap   |
      | name      | game-config |
    Then the output should match:
      | Name.*game-config |
      | game.properties   |
      | ui.properties     |
    When I get project configmap named "game-config" as YAML
    Then the output by order should match:
      | game.properties: \|                  |
      | enemies=aliens                       |
      | lives=3                              |
      | enemies.cheat=true                   |
      | enemies.cheat.level=noGoodRotten     |
      | secret.code.passphrase=UUDDLRLRBABAS |
      | secret.code.allowed=true             |
      | secret.code.lives=30                 |
      | ui.properties: \|                    |
      | color.good=purple                    |
      | color.bad=yellow                     |
      | allow.textmode=true                  |
      | how.nice.to.look=fairlyNice          |
      | name: game-config                    |

  # @author xiuli@redhat.com
  # @case_id OCP-16721
  @inactive
  Scenario: Changes to ConfigMap should be auto-updated into container
    Given I have a project
    Given I obtain test data file "configmap/configmap.json"
    When I run the :create client command with:
      | f | configmap.json |
    Then the step should succeed
    Given I obtain test data file "configmap/pod-configmap-volume3.yaml"
    When I run the :create client command with:
      | f | pod-configmap-volume3.yaml |
    Then the step should succeed
    Given the pod named "dapi-test-pod-1" status becomes :running
    When I execute on the pod:
      | cat | /etc/config/special.how |
    Then the step should succeed
    And the output should contain:
      | very |
    When I run the :patch client command with:
      | resource      | configmap                       |
      | resource_name | special-config                  |
      | p             | {"data":{"special.how":"well"}} |
    Then the step should succeed
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat | /etc/config/special.how |
    Then the output should contain:
      | well |
    """
    Then the step should succeed

