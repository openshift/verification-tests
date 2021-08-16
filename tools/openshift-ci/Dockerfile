FROM quay.io/centos/centos:8

LABEL vendor="Red Hat inc."
LABEL maintainer="OCP QE Team"

USER root

RUN set -x && \
    yum -y update && \
    INSTALL_PKGS="bsdtar git openssh-clients httpd-tools" && \
    yum install -y $INSTALL_PKGS && \
    GECKODRIVER_DOWNLOAD_URL="$(curl -sSL https://api.github.com/repos/mozilla/geckodriver/releases/latest | grep -Eo 'http.*linux64.tar.gz' | sed -E 's/.*(https[^"]*).*/\1/' | head -1)" && \
    curl -sSL $GITHUB_API_CURL_OPTS "$GECKODRIVER_DOWNLOAD_URL" | bsdtar -xvf - -C /usr/local/bin && \
    chmod +x /usr/local/bin/geckodriver && \
    curl -sSL https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -o /tmp/epel-release-latest-8.noarch.rpm && \
    yum install -y /tmp/epel-release-latest-8.noarch.rpm

ADD . /verification-tests/
RUN mv /tierN/ /verification-tests/tierN/
RUN set -x && \
    yum module reset ruby && \
    yum module -y enable ruby:2.7 && \
    yum module -y install ruby:2.7
RUN /verification-tests/tools/install_os_deps.sh
RUN /verification-tests/tools/hack_bundle.rb

RUN yum clean all -y && rm -rf /var/cache/yum /tmp/* /verification-tests/Gemfile.lock
