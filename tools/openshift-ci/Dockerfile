FROM quay.io/centos/centos:stream8

LABEL vendor="Red Hat inc."
LABEL maintainer="OCP QE Team"
USER root

ARG YQ_VERSION="v4.30.8"
RUN set -x && \
    declare -A YQ_HASH=([amd64]='6c911103e0dcc54e2ba07e767d2d62bcfc77452b39ebaee45b1c46f062f4fd26' \
                        [arm64]='95092e8b5332890c46689679b5e4360d96873c025ad8bafd961688f28ea434c7') && \
    arch="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')" && \
    YQ_URI="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${arch}" && \
    curl -sSL "${YQ_URI}" -o /usr/local/bin/yq && \
    echo "${YQ_HASH[$arch]} */usr/local/bin/yq" | sha256sum --strict --status --check && \
    chmod +x /usr/local/bin/yq

RUN set -x && \
    yum -y update && \
    INSTALL_PKGS="bsdtar git openssh-clients httpd-tools rsync" && \
    yum install -y $INSTALL_PKGS && \
    yum install -y --setopt=tsflags=nodocs https://dl.google.com/linux/direct/google-chrome-stable_current_$(uname -m).rpm && \
    CHROMEDRIVER_URL="https://chromedriver.storage.googleapis.com" && \
    CHROMEDRIVER_VERSION=$(curl -sSL "$CHROMEDRIVER_URL/LATEST_RELEASE") && \
    curl -sSL "$CHROMEDRIVER_URL/$CHROMEDRIVER_VERSION/chromedriver_linux64.zip" | bsdtar --no-same-owner --no-same-permissions -xvf - -C /usr/local/bin && \
    GECKODRIVER_SPEC="https://api.github.com/repos/mozilla/geckodriver/releases/latest" && \
    GECKODRIVER_RE='^.*"browser_download_url": ?"(http[^"]*linux64.tar.gz)".*$' && \
    curl -sSL $GITHUB_API_CURL_OPTS "$GECKODRIVER_SPEC" | sed -En "s#$GECKODRIVER_RE#\1#p" | xargs -d '\n' curl -sSL | bsdtar -xvf - -C /usr/local/bin && \
    chmod +x /usr/local/bin/chromedriver /usr/local/bin/geckodriver && \
    JQ_SPEC="https://api.github.com/repos/stedolan/jq/releases/latest" && \
    JQ_RE='^.*"browser_download_url": ?"(http[^"]*jq-linux64)".*$' && \
    curl -sSL $GITHUB_API_CURL_OPTS "$JQ_SPEC" | sed -En "s#$JQ_RE#\1#p" | xargs -d '\n' curl -sSL -o /usr/local/bin/jq && \
    chmod +x /usr/local/bin/jq && \
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm  && \
    yum install -y python38 python38-pip && \
    mkdir --parents /opt/python-env && \
    python3.8 -m venv /opt/python-env/ansible2.9 && \
    source /opt/python-env/ansible2.9/bin/activate && \
      pip install --upgrade pip setuptools && \
      pip install 'ansible < 2.10' && \
    deactivate && \
    python3.8 -m venv /opt/python-env/ansible-core && \
    source /opt/python-env/ansible-core/bin/activate && \
      pip install --upgrade pip setuptools && \
      pip install 'ansible-core < 2.14' && \
    deactivate && \
    yum module reset ruby && \
    yum module -y enable ruby:2.7 && \
    yum module -y install ruby:2.7 && \
    yum clean all -y && \
    rm -rf /var/cache/yum /var/tmp/* /tmp/*

ADD . /verification-tests/

RUN set -x && \
    mv /tierN/ /verification-tests/features/tierN/ && \
    chgrp -R 0 /verification-tests && \
    chmod -R g=u /verification-tests && \
    /verification-tests/tools/install_os_deps.sh && \
    /verification-tests/tools/hack_bundle.rb && \
    yum clean all -y && \
    rm -rf /var/cache/yum /var/tmp/* /tmp/* /verification-tests/Gemfile.lock

# Add ansible playbooks
RUN git clone https://github.com/openshift/openshift-ansible.git /usr/share/ansible/openshift-ansible && \
    chmod -R g=rwx /usr/share/ansible/openshift-ansible

# Fixing OCPQE-11756
RUN set -x && \
    mkdir /.ansible /.local && \
    chmod -R 777 /.ansible /.local
