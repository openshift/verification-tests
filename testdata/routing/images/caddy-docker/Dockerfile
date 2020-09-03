# Original caddy-docker build file.
FROM alpine:latest

RUN apk add --update openssh-client git tar curl wget
RUN rm -rf /var/cache/apk/*

# The original binary has been removed from this repo
# ensure a latest copy of caddy binary is downloaded and placed in the same relative directory before uncommenting the below line 
# and triggering the build.
# COPY caddy /usr/bin/

RUN chmod 0755 /usr/bin/caddy

EXPOSE 8080 8443
WORKDIR /srv

COPY Caddyfile /etc/caddy/Caddyfile
COPY public/ /srv/public/
COPY publics/ /srv/publics/
COPY certs/ /srv/certs

ENTRYPOINT ["/usr/bin/caddy", "--conf", "/etc/caddy/Caddyfile"]

