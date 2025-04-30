ARG PHP_VERSION="8.4"
FROM unit:php${PHP_VERSION}

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
RUN apt-get update && \
    apt-get install -y jq && \
    apt-get clean

COPY config/write-php-config.sh /docker-entrypoint.d/
COPY config/write-unit-config.sh /docker-entrypoint.d/

# Make the entrypoint run through bash.
RUN sed -i "1s/.*/#\!\/usr\/bin\/env bash/" /usr/local/bin/docker-entrypoint.sh

# Core configuration
ENV php.xdebug.client_host="host.docker.internal" \
    php.xdebug.mode="develop,debug"
