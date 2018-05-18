FROM alpine:3.7

ENV CHE_SYNC_VERSION=2.0.1 \
    UNISON_VERSION=2.48.4 \
    CHE_HOST= \
    CHE_USER= \
    CHE_PASS= \
    CHE_TOTP= \
    CHE_NAMESPACE= \
    CHE_WORKSPACE= \
    CHE_PROJECT= \
    SSH_USER=user \
    UNISON=/mount/.unison \
    UNISONLOCALHOSTNAME=che-local \
    UNISON_PROFILE= \
    UNISON_REPEAT=watch

ENTRYPOINT ["/entrypoint.sh"]

RUN apk add --no-cache bash curl ncurses jq openssh unison=~${UNISON_VERSION} && \
    addgroup -g 1000 -S user && \
    adduser -u 1000 -DS -h /home/user -s /sbin/nologin -g user -G user user && \
    mkdir /mount /home/user/.ssh && chown user:user /mount /home/user/.ssh

WORKDIR /home/user

USER user

COPY entrypoint.sh /
