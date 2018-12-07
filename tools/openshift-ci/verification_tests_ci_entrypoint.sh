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

# Generate the cucumber file list from the case id lookup table
# set Internal Field Separator for the file to the newline char
IFS=$'\n'
for i in $(cat < "case_id_lookup_table.txt"); do
  COMMAND_STRING=$COMMAND_STRING$(echo " ";echo $i | awk -F '|' '{print $2}')
done

/usr/bin/scl enable rh-git29 rh-ror50 -- cucumber -p junit -f $BUSHSLICER_TEST_FORMAT -o $BUSHSLICER_TEST_RESULTS $COMMAND_STRING
