#!/bin/bash

export TOOLS_HOME=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Setup git
function setup_git()
{
    git config --global --get user.name || \
        git config --global user.name "$USER"
    git config --global --get user.email || \
        git config --global user.email "$USER@redhat.com"
}

function is_ruby_proper_version()
{
  ruby -e 'exit Gem::Version.new("2.3") <= Gem::Version.new(RUBY_VERSION)'
}

function install_rvm_if_ruby_is_outdated()
{
    if ! is_ruby_proper_version; then
        # see http://10.66.129.213/index.php/archives/372/ for RHEL notes
        gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
        curl -sSL https://get.rvm.io | bash -s stable --ruby=2.6.2
        source /usr/local/rvm/scripts/rvm
    fi
}
#################################################
############ system-wide functions ##############
#################################################

# Prints operating system
function os_type()
{
    fileName='/etc/os-release'
    if [ -f "${fileName}" ]; then
        if grep -iq 'ID=fedora' "${fileName}" ; then
            version=`sed -rn 's/^VERSION_ID=([0-9]+)$/\1/p' < "${fileName}"`
            if [ $version -ge 22 ]; then
                echo fedora_dnf; return 0
            else
                echo fedora ; return 0
            fi
        fi
        grep -i -q "CentOS .* 7"  "${fileName}" && { echo "centos7"; return 0; }
        grep -i -q "CentOS .* 8"  "${fileName}" && { echo "centos8"; return 0; }
        grep -i -q 'debian'       "${fileName}" && { echo "debian"; return 0; }
        grep -i -q 'mint'         "${fileName}" && { echo "mint"; return 0; }
        grep -i -q "Red Hat .* 6" "${fileName}" && { echo "rhel6"; return 0; }
        grep -i -q "Red Hat .* 7" "${fileName}" && { echo "rhel7"; return 0; }
        grep -i -q "Red Hat .* 8" "${fileName}" && { echo "rhel8"; return 0; }
        grep -i -q "Red Hat .* 9" "${fileName}" && { echo "rhel9"; return 0; }
        grep -i -q 'ubuntu'       "${fileName}" && { echo "ubuntu"; return 0; }
    elif [ -f /usr/bin/sw_vers ]; then
        sw_vers | grep 'ProductName:' | awk '{ print substr($0, index($0,$2)) }'
        return 0;
    fi
    echo 'ERROR: Unsupported OS type'
    return 1
}

# Will return the method of installing system packages: DNF/DEB/YUM
function os_pkg_method()
{
    case "$(os_type)" in
        fedora_dnf ) echo "DNF" ;;
        fedora | rhel* | centos* ) echo "YUM" ;;
        ubuntu | debian | mint ) echo "DEB" ;;
        * ) echo "TAR" ;;
    esac
}

# Return 'sudo' if the user's not root
function need_sudo()
{
    # for Mac, brew prohibits user to run it as sudo
    if [ `id -u` != "0" -a "$(os_type)" != "Mac OS X" ]; then
        echo 'sudo'
    else
        echo ''
    fi
}

# Setup sudo configuration
function setup_sudo()
{
    $(need_sudo) grep BUSHSLICER_SETUP /etc/sudoers && return
    $(need_sudo) cat > /etc/sudoers <<END
# BUSHSLICER_SETUP #
Defaults    env_reset
Defaults    env_keep =  "COLORS DISPLAY HOSTNAME HISTSIZE INPUTRC KDEDIR LS_COLORS"
Defaults    env_keep += "MAIL PS1 PS2 QTDIR USERNAME LANG LC_ADDRESS LC_CTYPE"
Defaults    env_keep += "LC_COLLATE LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES"
Defaults    env_keep += "LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE"
Defaults    env_keep += "LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"

Defaults    secure_path = /usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

root    ALL=(ALL)       ALL
%wheel  ALL=NOPASSWD: ALL
# BUSHSLICER_SETUP #
END
}

function get_random_str()
{
    LEN=10
    [ -n "$1" ] && LEN=$1
    echo "$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c $LEN)"
}

function random_email()
{
    echo "cucushift+$(get_random_str)@redhat.com"
}
