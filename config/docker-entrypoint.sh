#!/usr/bin/env bash
set -e

# Run startup scripts.
for f in $(/usr/bin/find /docker-entrypoint.d/ -type f -name "*.sh"); do
  echo "$0: Launching $f";
  "$f"
done

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- php "$@"
fi

exec "$@"