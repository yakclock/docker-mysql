
FROM bodsch/docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version "1.5.0"

EXPOSE 3306

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache add \
    mysql \
    mysql-client \
    pwgen && \
  rm -rf /tmp/* /var/cache/apk/*

ADD rootfs/ /

CMD [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
