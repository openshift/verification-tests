Feature: oc related features

  # @author chezhang@redhat.com
  # @case_id OCP-11565
  @inactive
  Scenario: OCP-11565:Node kubectl secret subcommand - help
    Given I have a project
    When I run the :create_secret client command with:
      | secret_type | |
      | h           | |
    Then the step should succeed
    And the output should contain:
      | Available Commands:                   |
      | docker-registry                       |
      | generic                               |
    When I run the :create_secret client command with:
      | secret_type | |
      | help        | |
    Then the step should succeed
    And the output should contain:
      | Available Commands:                   |
      | docker-registry                       |
      | generic                               |
    When I run the :create_secret client command with:
      | secret_type | generic |
      | h           |         |
    Then the step should succeed
    And the output should contain:
      | Options:             |
      | --dry-run=           |
      | --from-env-file=     |
      | --from-file=         |
      | --from-literal=      |
      | -o, --output=        |
      | --save-config=       |
      | --template=          |
      | --type=              |
      | --validate=          |
    When I run the :create_secret client command with:
      | secret_type | generic |
      | help        |         |
    Then the step should succeed
    And the output should contain:
      | Options:             |
      | --dry-run=           |
      | --from-file=         |
      | --from-literal=      |
      | --generator=         |
      | -o, --output=        |
      | --save-config=       |
      | --template=          |
      | --type=              |
      | --validate=          |
    When I run the :create_secret client command with:
      | secret_type | docker-registry |
      | h           |                 |
    Then the step should succeed
    And the output should contain:
      | Options:             |
      | --docker-email=      |
      | --docker-password=   |
      | --docker-server=     |
      | --docker-username=   |
      | --dry-run=           |
      | --generator=         |
      | -o, --output=        |
      | --save-config=       |
      | --template=          |
      | --validate=          |
    When I run the :create_secret client command with:
      | secret_type | docker-registry |
      | help        |                 |
    Then the step should succeed
    And the output should contain:
      | Options:             |
      | --docker-email=      |
      | --docker-password=   |
      | --docker-server=     |
      | --docker-username=   |
      | --dry-run=           |
      | --generator=         |
      | -o, --output=        |
      | --save-config=       |
      | --template=          |
      | --validate=          |

  # @author chezhang@redhat.com
  # @case_id OCP-10812
  @inactive
  Scenario: OCP-10812:Node Check `oc autoscale` help info
    Given I have a project
    When I run the :autoscale client command with:
      | name  | :false |
      | h     | |
    Then the step should succeed
    And the output should contain:
      | Options:             |
      | --cpu-percent=       |
      | --dry-run=           |
      | -f, --filename=      |
      | --generator=         |
      | --max=               |
      | --min=               |
      | --name=              |
      | -o, --output=        |
      | --record=            |
      | --save-config=       |
      | --template=          |
    When I run the :autoscale client command with:
      | name  | :false |
      | help  | |
    Then the step should succeed
    And the output should contain:
      | Options:             |
      | --cpu-percent=       |
      | --dry-run=           |
      | -f, --filename=      |
      | --generator=         |
      | --max=               |
      | --min=               |
      | --name=              |
      | -o, --output=        |
      | --record=            |
      | --save-config=       |
      | --template=          |
    When I run the :help client command with:
      | command_name | autoscale |
    Then the step should succeed
    And the output should contain:
      | Options:             |
      | --cpu-percent=       |
      | --dry-run=           |
      | -f, --filename=      |
      | --generator=         |
      | --max=               |
      | --min=               |
      | --name=              |
      | -o, --output=        |
      | --record=            |
      | --save-config=       |
      | --template=          |

