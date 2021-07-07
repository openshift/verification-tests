FROM quay.io/centos/centos:7

LABEL vendor="Red Hat inc."
LABEL maintainer="AOS QE Team"

USER root


RUN set -x && \
    yum -y update && \
    SCL_BASE_PKGS="centos-release-scl scl-utils-build" && \
    INSTALL_PKGS="rh-ruby26 rh-ruby26-ruby-devel rh-git218 bsdtar" && \
    yum install -y --enablerepo=centosplus --setopt=skip_missing_names_on_install=False $SCL_BASE_PKGS && \
    yum install -y --enablerepo=centosplus --setopt=skip_missing_names_on_install=False $INSTALL_PKGS && \
    GECKODRIVER_DOWNLOAD_URL="$(curl -sSL https://api.github.com/repos/mozilla/geckodriver/releases/latest | grep -Eo 'http.*linux64.tar.gz' | sed -E 's/.*(https[^"]*).*/\1/' | head -1)" && \
    curl -sSL "$GECKODRIVER_DOWNLOAD_URL" | bsdtar -xvf - -C /usr/local/bin && \
    chmod +x /usr/local/bin/geckodriver && \
    curl -sSL https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -o /tmp/epel-release-latest-7.noarch.rpm && \
    yum install -y /tmp/epel-release-latest-7.noarch.rpm

RUN scl enable rh-git218 "git clone https://github.com/openshift/verification-tests.git /verification-tests/" && \
    scl enable rh-git218 "git clone https://github.com/openshift/cucushift.git /verification-tests/tierN/"

RUN scl enable rh-ruby26 /verification-tests/tools/install_os_deps.sh
RUN scl enable rh-ruby26 /verification-tests/tools/hack_bundle.rb


RUN yum clean all -y && rm -rf /var/cache/yum /tmp/*
