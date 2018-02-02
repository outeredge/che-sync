FROM alpine:3.7

ENV UNISON_VERSION 2.48.4

VOLUME /mount

ENTRYPOINT ["/entrypoint.sh"]

RUN apk add --no-cache bash curl jq openssh unison=~${UNISON_VERSION} && \
    mkdir -p $HOME/.unison $HOME/.ssh

COPY entrypoint.sh /