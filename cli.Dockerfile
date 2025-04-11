ARG PHP_VERSION="8.3"
FROM php:${PHP_VERSION}-cli-bookworm

WORKDIR /srv

# For running this image directly.
ARG PUID=1000
ARG PGID=1000
ENV PGID=$PGID PUID=$PUID
RUN addgroup --gid "$PGID" app
RUN adduser --uid "$PUID" \
            --ingroup app \
            --shell $(command -v bash) \
            --disabled-password \
            app

# For images building off of this.
ONBUILD ARG PUID=1000
ONBUILD ARG PGID=1000
ONBUILD ENV PGID=$PGID PUID=$PUID
ONBUILD RUN usermod -u "$PUID" app
ONBUILD RUN groupmod -g "$PGID" app

RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

COPY config/write-php-config.sh /docker-entrypoint.d/

# Replace the entrypoint to allow it to use the startup scripts.
COPY config/docker-entrypoint.sh /usr/local/bin/docker-php-entrypoint

# Core configuration
ENV php.xdebug.client_host="host.docker.internal" \
    php.xdebug.cli_color="true"