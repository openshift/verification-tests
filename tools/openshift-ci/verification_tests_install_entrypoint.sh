#!/bin/bash -xe

# This script is used as entrypoint to start Flexy installer based on
# environment variables. Useful to run it from inside a container.
# see example install-variables-example.sh

export WORKSPACE=`pwd`/flexy


# First clone verification-tests repo itself
# TODO: read variables to allow different fork or branch of it
GIT_FLEXY_URI="https://github.com/openshift/verification-tests.git"
git clone --depth 1 --single-branch "$GIT_FLEXY_URI" "$WORKSPACE"
cd "$WORKSPACE"

# Go over all GIT_xyz_URI environment variables and clone them
for git_var in "${!GIT_@}"; do
  # TODO: read variables for athentication
  if [[ "$git_var" == *_URI ]]; then
    git_name="${git_var#GIT_}"
    git_name="${git_name%_URI}"
    git_dir="${git_name,,}"
    git_dir="${git_dir//_/-}"

    git_branch_var="GIT_${git_name}_BRANCH"
    if [[ "${!git_branch_var}" ]]; then
      git_branch="--branch $git_branch"
    fi
    git clone --depth 1 --single-branch $git_branch "${!git_var}" $git_dir

    set +x
    git_crypt_var="GIT_${git_name}_GIT_CRYPT"
    if [[ "${!git_crypt_var}" ]]; then
      cd $git_dir
      git_crypt_key_file=`mktemp`
      printf "${!git_crypt_var}" | base64 --decode > "$git_crypt_key_file"
      git crypt unlock "$git_crypt_key_file"
      rm -f "$git_crypt_key_file"
      unset $git_crypt_var
      cd ..
    fi
    set -x
  fi
done


# TODO: sed output to filter out printig of _CREDENTIALS and _PASSWORD variables
export BUSHSLICER_HOSTS_SPEC_FILE="$WORKSPACE"/host.spec
export BUSHSLICER_VMINFO_YAML="$WORKSPACE"/vminfo.yml
rm -f "$BUSHSLICER_HOSTS_SPEC_FILE" "$BUSHSLICER_VMINFO_YAML"
ruby --version
bundle check --gemfile=tools/Gemfile || tools/hack_bundle.rb
bash -l -c "ruby tools/launch_instance.rb template -c '${VARIABLES_LOCATION}' -l '${INSTANCE_NAME_PREFIX}'"

