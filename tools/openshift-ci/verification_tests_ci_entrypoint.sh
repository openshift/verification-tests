#!/bin/bash

[[ -z "$BUSHSLICER_TEST_ENVIRONMENT" ]] && { echo "BUSHSLICER_TEST_ENVIRONMENT not set"; exit 1; }
[[ -z "$BUSHSLICER_TEST_CLUSTER" ]] && { echo "BUSHSLICER_TEST_CLUSTER not set"; exit 1; }
[[ -z "$BUSHSLICER_TEST_TOKEN" ]] && { echo "BUSHSLICER_TEST_TOKEN not set"; exit 1; }
[[ -z "$BUSHSLICER_TEST_CONFIG" ]] && { echo "BUSHSLICER_TEST_CONFIG not set"; exit 1; }
[[ -z "$BUSHSLICER_TEST_FORMAT" ]] && { echo "BUSHSLICER_TEST_FORMAT not set"; exit 1; }
if [ -z "$BUSHSLICER_TEST_RESULTS" ]
then
      echo "BUSHSLICER_TEST_RESULTS not set, setting to current dir"
      export BUSHSLICER_TEST_RESULTS="$PWD/junit-report"
fi


export BUSHSLICER_DEFAULT_ENVIRONMENT="$BUSHSLICER_TEST_ENVIRONMENT"
[[ -z "$BUSHSLICER_DEFAULT_ENVIRONMENT" ]] && { echo "BUSHSLICER_DEFAULT_ENVIRONMENT not set"; exit 1; }

export OPENSHIFT_ENV_$(echo "$BUSHSLICER_TEST_ENVIRONMENT" | awk '{print toupper($0)}')_HOSTS="${BUSHSLICER_TEST_CLUSTER}:etcd:master:node"
export OPENSHIFT_ENV_$(echo "$BUSHSLICER_TEST_ENVIRONMENT" | awk '{print toupper($0)}')_USER_MANAGER_USERS=:"${BUSHSLICER_TEST_TOKEN}"
export OPENSHIFT_ENV_$(echo "$BUSHSLICER_TEST_ENVIRONMENT" | awk '{print toupper($0)}')_WEB_CONSOLE_URL=https://${BUSHSLICER_TEST_CLUSTER}/console

export TESTENV="BUSHSLICER_V3"
export BUSHSLICER_CONFIG="${BUSHSLICER_TEST_CONFIG}"
unset BUSHSLICER_DEBUG_AFTER_FAIL

/usr/bin/scl enable rh-git29 rh-ror50 -- cucumber -p junit -f $BUSHSLICER_TEST_FORMAT -o $BUSHSLICER_TEST_RESULTS \
  features/online/logging.feature:5 \
  features/web/settings.feature:164 \
  features/build/dockerbuild.feature:216 \
  features/build/buildlogic.feature:226 \
  features/build/buildlogic.feature:246 \
  features/build/dockerbuild.feature:183 \
  features/cli/job.feature:543 \
  features/cli/secrets.feature:698 \
  features/cli/oc_expose.feature:5 \
  features/cli/event.feature:51 \
  features/cli/downwardapi.feature:34 \
  features/cli/downwardapi.feature:5 \
  features/cli/oc_delete.feature:84 \
  features/cli/create.feature:5 \
  features/cli/build.feature:207 \
  features/node/seccomp.feature:5 \
  features/cli/secrets.feature:365 \
  features/cli/deploy.feature:435 \
  features/web/hooks.feature:5 \
  features/cli/oc_env.feature:5 \
  features/cli/deploy.feature:558 \
  features/web/membership.feature:5 \
  features/storage/persistent_volume.feature:42 \
  features/cli/oc_import_image.feature:120 \
  features/build/buildconfig.feature:5 \
  features/build/buildconfig.feature:42 \
  features/cli/deploy.feature:415 \
  features/cli/oc_idle.feature:121 \
  features/cli/build.feature:284 \
  features/cli/deploy.feature:482 \
  features/web/project.feature:5 \
  features/build/buildlogic.feature:193 \
  features/cli/deploy.feature:539 \
  features/build/buildlogic.feature:41 \
  features/cli/deployment.feature:268 \
  features/cli/projects.feature:5 \
  features/cli/oc_tag.feature:60 \
  features/cli/oc_idle.feature:46 \
  features/cli/deploy.feature:467 \
  features/build/dockerbuild.feature:19 \
  features/cli/oc_delete.feature:110 \
  features/cli/oc_set_deployment_hook.feature:5 \
  features/web/k8s-deployments.feature:5 \
  features/cli/oc_secrets.feature:57 \
  features/web/routes.feature:5 \
  features/cli/deploy.feature:402 \
  features/images/jenkins.feature:261 \
  features/cli/create.feature:55 \
  features/cli/oc_idle.feature:81 \
  features/cli/oc_volume.feature:51 \
  features/cli/oc_import_image.feature:102 \
  features/cli/oc_volume.feature:6 \
  features/cli/oc_import_image.feature:166 \
  features/cli/build.feature:223 \
  features/web/deployments.feature:42 \
  features/cli/deployment.feature:465 \
  features/cli/scale.feature:52 \
  features/cli/oc_import_image.feature:150 \
  features/cli/secrets.feature:30 \
  features/build/dockerbuild.feature:144 \
  features/build/dockerbuild.feature:128 \
  features/build/buildconfig.feature:26 \
  features/cli/pod.feature:111 \
  features/cli/pod.feature:53 \
  features/web/check_page.feature:6 \
  features/cli/configmap.feature:6 \
  features/cli/build.feature:663 \
  features/cli/serviceaccount.feature:5 \
  features/cli/secrets.feature:654 \
  features/web/create.feature:110 \
  features/cli/replica_set.feature:6 \
  features/build/buildlogic.feature:117 \
  features/cli/rsh.feature:5 \
  features/cli/oc_import_image.feature:39 \
  features/web/settings.feature:145 \
  features/cli/build.feature:638 \
  features/cli/secrets.feature:624 \
  features/cli/job.feature:209 \
  features/web/deployments.feature:142 \
  features/cli/secrets.feature:5 \
  features/cli/deploy.feature:34 \
  features/web/service.feature:5 \
  features/cli/secrets.feature:591 \
  features/cli/allinone-volume.feature:5 \
  features/cli/deployment.feature:170 \
  features/build/buildlogic.feature:5 \
  features/cli/oc_import_image.feature:86 \
  features/web/create.feature:6 \
  features/cli/hpa.feature:73 \
  features/cli/deploy.feature:795 \
  features/build/stibuild.feature:5 \
  features/cli/build.feature:132 \
  features/cli/hpa.feature:120 \
  features/cli/deploy.feature:71 \
  features/cli/serviceaccount.feature:63 \
  features/cli/job.feature:5 \
  features/cli/oc_import_image.feature:179 \
  features/cli/oc_secrets.feature:221 \
  features/cli/deploy.feature:686 \
  features/web/deployments.feature:100 \
  features/cli/oc_help.feature:5 \
  features/cli/build.feature:184 \
  features/cli/oc_import_image.feature:71 \
  features/build/buildlogic.feature:151 \
  features/cli/build.feature:5 \
  features/cli/oc_idle.feature:215 \
  features/cli/projects.feature:137 \
  features/cli/deploy.feature:445 \
  features/cli/oc_set_probe.feature:5 \
  features/cli/policy.feature:496 \
  features/cli/oc_set_probe.feature:107 \
  features/cli/configmap.feature:295 \
  features/build/buildlogic.feature:53 \
  features/cli/downwardapi.feature:18 \
  features/web/deployments.feature:6 \
  features/cli/scale.feature:5 \
  features/cli/pod.feature:143 \
  features/cli/oc_set_probe.feature:62 \
  features/cli/deploy.feature:370 \
  features/cli/configmap.feature:272 \
  features/cli/route.feature:5 \
  features/cli/oc_set_env.feature:58 \
  features/cli/deploy.feature:763 \
  features/build/stibuild.feature:59 \
  features/web/service-catalog/project.feature:5 \
  features/online/metrics.feature:5 \
  features/admin/scheduler.feature:5 \
  features/cli/oc_secrets.feature:5 \
  features/web/check_page.feature:26 \
  features/cli/deploy.feature:272 \
  features/cli/deploy.feature:5 \
  features/web/pod.feature:5 \
  features/rest/webhook.feature:52 \
  features/cli/configmap.feature:37 \
  features/cli/secrets.feature:413 \
  features/cli/build.feature:361 \
  features/cli/oc_set_env.feature:5 \
  features/build/dockerbuild.feature:5 \
  features/cli/oc_set_build_hook.feature:6 \
  features/web/scale.feature:5 \
  features/cli/configmap.feature:75 \
  features/cli/oc_tag.feature:5 \
  features/cli/deploy.feature:188 \
  features/cli/secrets.feature:62 \
  features/cli/oc_secrets.feature:168 \
  features/cli/deployment.feature:374 \
  features/cli/deploy.feature:662 \
  features/web/overview.feature:181 \
  features/build/env.feature:5 \
  features/web/check_page.feature:42 \
  features/cli/deployment.feature:5 \
  features/cli/deployment.feature:78 \
  features/cli/oc_idle.feature:5 \
  features/cli/pod.feature:161 \
  features/cli/job.feature:84 \
  features/build/buildlogic.feature:17 \
  features/cli/build.feature:71 \
  features/web/routes.feature:37 \
  features/cli/serviceaccount.feature:30 \
  features/web/create.feature:256 \
  features/build/dockerbuild.feature:111 \
  features/cli/resources.feature:5 \
  features/web/configmap.feature:5 \
  features/cli/deploy.feature:150 \
  features/cli/policy.feature:379 \
  features/cli/deploy.feature:321 \
  features/cli/configmap.feature:115 \
  features/cli/configmap.feature:179 \
  features/cli/event.feature:92 \
  features/containers/containers.feature:7 \
  features/cli/job.feature:192 \
  features/networking/pod.feature:42 \
  features/cli/policy.feature:408 \
  features/images/jenkins.feature:382 \
  features/web/configmap.feature:63 \
  features/cli/oc_set_deployment_hook.feature:1
