export BUSHSLICER_DEBUG_AFTER_FAIL=1
export BUSHSLICER_DEFAULT_ENVIRONMENT=ocp4
export OPENSHIFT_ENV_OCP4_HOSTS=api.wjuos32044h.qe.devcluster.openshift.com:lb
export OPENSHIFT_ENV_OCP4_USER_MANAGER_USERS=testuser-0:5QDttaYe6g-t,testuser-1:vqAhSzhdtwle,testuser-2:J6OKXWdVdU32
export BUSHSLICER_CONFIG='
  global:
    browser: chrome
  environments:
    ocp4:
      admin_creds_spec: "https://openshift-qe-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/Launch%20Environment%20Flexy/85793/artifact/workdir/install-dir/auth/kubeconfig/*view*/"
      version: "4.4"
      idp: "flexy-htpasswd-provider"
      admin_console_url: "https://oauth-openshift.apps.wjuos32044h.qe.devcluster.openshift.com"
'
