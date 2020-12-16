Feature: Test features
  # @author kewang@redhat.com
  @admin
  Scenario: Quick test for step definitions of PR 1719
    Given the master version >= "4.6"
    Given I switch to cluster admin pseudo user      

    # Set WriteRequestBodies profile to audit log
    Given as admin I successfully merge patch resource "apiserver/cluster" with:
      | {"spec": {"audit": {"profile": "WriteRequestBodies"}}} |
    And I register clean-up steps:
    # Set original Default profile to audti log
    """
    Given as admin I successfully merge patch resource "apiserver/cluster" with:
      | {"spec": {"audit": {"profile": "Default"}}} |
    Given I wait up to 100 seconds for operator "kube-apiserver" to become conditions: "True True"
    Given I wait up to 1200 seconds for operator "kube-apiserver" to become conditions: "Available=True Progressing=False Degraded=False"
    """
    Given I wait up to 100 seconds for operator "kube-apiserver" to become conditions: "Progressing=True"
    Given I wait up to 1200 seconds for operator "kube-apiserver" to become conditions: "True False False"
    Given I wait up to 100 seconds for operator "kube-apiserver" to become conditions: "Available=True"
    Given I wait up to 100 seconds for operator "kube-apiserver" to become conditions: "Available=True Progressing=False"
    Given I wait up to 180 seconds for operator "kube-apiserver" to become conditions: "Available=True Progressing=False Degraded=False Upgradeable=True"
    Given I wait up to 100 seconds for operator "kube-apiserver" to become conditions: "True"
    Given I wait up to 100 seconds for operator "kube-apiserver" to become conditions: "True False False"
    Given I wait up to 100 seconds for operator "kube-apiserver" to become conditions: "True False False True"
    Given I wait up to 100 seconds for operator "kube-apiserver" to become conditions: ""      
