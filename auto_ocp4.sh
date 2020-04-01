export BUSHSLICER_DEBUG_AFTER_FAIL=1
export BUSHSLICER_DEFAULT_ENVIRONMENT=ocp4
export OPENSHIFT_ENV_OCP4_HOSTS=api.pmali-01.0401-717.qe.rhcloud.com:lb
export OPENSHIFT_ENV_OCP4_USER_MANAGER_USERS=testuser-0:DA5xzb0J0W3V,testuser-1:Hixr0sxAkSkf,testuser-2:Fxagd5hJr5fi
export BUSHSLICER_CONFIG='
  global:
    browser: chrome
  environments:
    ocp4:
      admin_creds_spec: "https://openshift-qe-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/Launch%20Environment%20Flexy/87391/artifact/workdir/install-dir/auth/kubeconfig"
      version: "4.4"
      idp: "flexy-htpasswd-provider"
      admin_console_url: "oauth-openshift.apps.pmali-01.0401-717.qe.rhcloud.com"
'
