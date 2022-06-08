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

  # @author kewang@redhat.com
  @admin
  Scenario: Quick test for baremetal cluster init
    # Currently we don't support baremetal iaas, but the iaas type will be checked by some cases with baremetal cluster
    # The platform type from the baremetal openshift we get is None, we need to handle this type and return one value(even if it's nil), 
    # ensure check iaas type with baremetal without exception and exit.
    Given evaluation of `env.iaas[:type] == "aws" ? "1500" : "1300"` is stored in the :wait_time clipboard
