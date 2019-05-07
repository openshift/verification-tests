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

export BUSHSLICER_CONFIG="${BUSHSLICER_TEST_CONFIG}"

cases=`curl "$0"` # $0 must be URL to white space separated case IDs
"$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"/case_id_splitter.rb file-line "$cases" | xargs -d '\n' /usr/bin/scl enable rh-git29 rh-ror50 -- cucumber -p junit -f $BUSHSLICER_TEST_FORMAT -o $BUSHSLICER_TEST_RESULTS
