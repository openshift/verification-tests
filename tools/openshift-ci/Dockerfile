FROM quay.io/centos/centos:8

LABEL vendor="Red Hat inc."
LABEL maintainer="OCP QE Team"
USER root

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
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm  && \
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

# Fixing OCPQE-11756
RUN set -x && \
    mkdir /.local && \
    chmod -R 777 /.local
