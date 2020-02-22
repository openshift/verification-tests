#!/bin/bash -xe

# This script is used as entrypoint to start Flexy installer based on
# environment variables. Useful to run it from inside a container.
# see example install-variables-example.sh

export WORKSPACE=`pwd`/flexy
export BUSHSLICER_VMINFO_YAML="$WORKSPACE"/vminfo.yml
export BUSHSLICER_HOSTS_SPEC_FILE="$WORKSPACE"/host.spec

case "$1" in

  "destroy")
    cd "$WORKSPACE"
    tools/launch_instance.rb terminate "$BUSHSLICER_VMINFO_YAML"
    exit 0
    ;;

  "fiddle")
    exec bash
    ;;

  "debug")
    # fall into a shell in case of an error
    trap "exec bash" ERR
    ;;

  ?*)
    echo "invalid argument '$1'" >&2
    exit 1
    ;;
esac

function git_clone() {
  local git_var_uri git_dir git_var_branch git_var_git_crypt \
        git_var_prefix git_branch git_crypt_key_file
  git_var_uri="$1"
  git_var_prefix="${git_var_uri%_URI}"
  git_dir="${git_var_prefix#GIT_}"
  git_dir="${git_dir,,}"
  git_dir="${git_dir//_/-}"

  git_var_branch="${git_var_prefix}_BRANCH"
  if [[ "${!git_var_branch}" ]]; then
    git_branch="--branch ${!git_var_branch}"
  fi
  # TODO: read variables for athentication
  git clone --depth 1 --single-branch $git_branch "${!git_var_uri}" $git_dir

  set +x
  git_var_git_crypt="${git_var_prefix}_GIT_CRYPT"
  if [[ "${!git_var_git_crypt}" ]]; then
    cd $git_dir
    git_crypt_key_file=`mktemp`
    printf "${!git_var_git_crypt}" | base64 --decode > "$git_crypt_key_file"
    git crypt unlock "$git_crypt_key_file"
    rm -f "$git_crypt_key_file"
    unset $git_var_git_crypt # unset var to avoid content leaking in the logs
    cd ..
  fi
  set -x
}

# First clone verification-tests repo itself
: ${FLEXY_URI:=https://github.com/openshift/verification-tests.git}
git_clone FLEXY_URI
cd "$WORKSPACE"

# Go over all GIT_xyz_URI environment variables and clone them
for git_var in "${!GIT_@}"; do
  if [[ "$git_var" == *_URI ]]; then
    git_clone $git_var
  fi
done

rm -f "$BUSHSLICER_HOSTS_SPEC_FILE" "$BUSHSLICER_VMINFO_YAML"
ruby --version
bundle check --gemfile=tools/Gemfile || tools/hack_bundle.rb
# TODO: sed output to filter out printig of _CREDENTIALS and _PASSWORD variables
bash -l -c "ruby tools/launch_instance.rb template -c '${VARIABLES_LOCATION}' -l '${INSTANCE_NAME_PREFIX}'"

