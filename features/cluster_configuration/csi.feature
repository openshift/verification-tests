Feature: Enable CSI in OCP cluster

  # @author piqin@redhat.com
  @admin
  @destructive
  Scenario: Enable cinder csi driver and create storage class for cinder driver
    Given I deploy "cinder" driver using csi
    Given I create storage class for "cinder" csi driver
    Given I checked "cinder" csi driver is running

  # @author piqin@redhat.com
  @admin
  @destructive
  Scenario: Enable cinder csi driver with specific version and create storage class for cinder driver
    Given I deploy "cinder" driver using csi with "v3.10.14-2" version
    Given I create storage class for "cinder" csi driver
    Given I checked "cinder" csi driver is running
