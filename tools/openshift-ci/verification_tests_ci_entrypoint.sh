#!/bin/bash

set -ex

export TOOLS_HOME=$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )

. "$TOOLS_HOME"/common.sh

TEST_CASES_URL="$1" # must be URL to new line separated case IDs

cases=`curl "$TEST_CASES_URL"`
cucumber_command="cucumber -p junit"

if ! is_ruby_proper_version && [[ "`os_type`" == "rhel7" || "`os_type`" == "centos7" ]]; then
  cucumber_command="/usr/bin/scl enable rh-git29 rh-ror50 -- $cucumber_command"
elif ! is_ruby_proper_version; then
  echo "Ruby not proper version, see tool/common.sh#is_ruby_proper_version"
fi

/usr/bin/scl enable rh-git29 rh-ror50 -- "$TOOLS_HOME"/case_id_splitter.rb file-line $cases | xargs -d '\n' $cucumber_command
