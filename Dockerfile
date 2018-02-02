FROM alpine:3.7

ENV UNISON_VERSION 2.48.4

VOLUME /mount

ENTRYPOINT ["/entrypoint.sh"]

RUN apk add --no-cache bash curl jq openssh unison=~${UNISON_VERSION} && \
    addgroup -g 1000 -S user && \
    adduser -u 1000 -DS -h /home/user -s /sbin/nologin -g user -G user user

COPY entrypoint.sh /

USER user

RUN mkdir -p /home/user/.unison /home/user/.ssh
