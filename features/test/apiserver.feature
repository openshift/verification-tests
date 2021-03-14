Feature: API server Test features
  # @author kewang@redhat.com
  @admin
  @destructive
  Scenario: Quick test for step definitions
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
    Given operator "kube-apiserver" becomes progressing within 100 seconds
    Given operator "kube-apiserver" becomes available/non-progressing/non-degraded within 1200 seconds
    """
    Given operator "kube-apiserver" becomes progressing
    Given operator "kube-apiserver" becomes available/non-progressing/non-degraded within 1200 seconds
    Given operator "kube-apiserver" becomes available/non-progressing within 100 seconds
    Given operator "kube-apiserver" becomes available/non-degraded within 100 seconds
    Given operator "kube-apiserver" becomes available within 100 seconds
    Given operator "kube-apiserver" becomes non-progressing within 100 seconds
    Given operator "kube-apiserver" becomes non-degraded within 100 seconds
