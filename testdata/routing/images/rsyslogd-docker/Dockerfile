# original rsyslogd build files. 
# "rsyslog.conf" file should be available in the same relative directory for the build to succeed
FROM alpine:latest
RUN     apk update && apk add rsyslog \
                              wget \
                              curl
RUN rm -rf /var/cache/apk/*
COPY   rsyslog.conf /etc/rsyslog.conf
ENTRYPOINT ["rsyslogd", "-n", "-f", "/etc/rsyslog.conf"]
EXPOSE 514/udp 514/tcp 8443/tcp 8080/tcp 8443/udp 8080/udp

