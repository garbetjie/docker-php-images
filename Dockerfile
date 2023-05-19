ARG PHP_VERSION
ARG ALPINE_VERSION=3.18

FROM alpine:$ALPINE_VERSION AS fs

RUN mkdir /tmp/root
RUN wget https://github.com/just-containers/s6-overlay/releases/download/v3.1.2.1/s6-overlay-noarch.tar.xz -P /tmp
RUN wget https://github.com/just-containers/s6-overlay/releases/download/v3.1.2.1/s6-overlay-$(uname -m).tar.xz -P /tmp
RUN tar -C /tmp/root/ -Jxpf /tmp/s6-overlay-noarch.tar.xz
RUN tar -C /tmp/root/ -Jxpf /tmp/s6-overlay-$(uname -m).tar.xz
RUN mkdir /tmp/root/app

COPY bin/ /tmp/root/usr/local/bin/

# Copy core services.
COPY services/ /tmp/root/etc/s6-overlay/s6-rc.d


FROM php:${PHP_VERSION}-alpine${ALPINE_VERSION} AS shared

STOPSIGNAL SIGTERM
ENTRYPOINT ["/init"]

COPY --from=fs /tmp/root/ /
WORKDIR /app

ENV PUID=1000 \
    PGID=1000

RUN set -ex; \
    apk add --no-cache shadow su-exec; \
    rm -rf /var/www; \
    addgroup -g "$PGID" app; \
    adduser -s /bin/sh -G app -u "$PUID" -D app


FROM shared AS www

COPY nginx.conf /etc/nginx/nginx.conf

RUN set -e; \
    apk add --no-cache nginx; \
    mkdir -p /etc/nginx/server.d; \
    rm -rf /var/www /etc/nginx/http.d/*.conf; \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/nginx \
          /etc/s6-overlay/s6-rc.d/user/contents.d/fpm; \
    mkdir -p /var/tmp/nginx /var/lib/nginx


FROM shared AS cli

CMD ["/command/with-contenv", "su-exec", "app:app", "php", "-a"]