#!/bin/sh
set -e

# Ensure PHP config is written.
/usr/local/bin/docker-php-config.sh

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- php "$@"
fi

exec "$@"