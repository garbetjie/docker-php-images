#!/usr/bin/env bash

# Write the configured environment variables to the PHP config.

echo "" | awk '{
  for (key in ENVIRON) {
    if (! (key ~ /^PHP__/)) {
      continue
    }

    name = substr(key, 6)
    name = tolower(name)
    gsub(/__/, ".", name)

    print name "=" ENVIRON[key]
  }
}' > "$PHP_INI_DIR/conf.d/zz-docker-startup.ini"


# Ensure the session path exists.

if [ "$(php -r "echo ini_get('session.save_handler');")" = "files" ]; then
  session_save_path="$(php -r "echo ini_get('session.save_path');")"

  if [ "$session_save_path" != "" ] && [ ! -d "$session_save_path" ]; then
    mkdir -p "$session_save_path"
    chown -R app:app "$session_save_path"
  fi
fi