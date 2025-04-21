#!/usr/bin/env bash

set -e

# Taken straight from /usr/local/bin/docker-entrypoint.sh
curl_put()
{
    RET=$(/usr/bin/curl -s -w '%{http_code}' -X PUT --data-binary @$1 --unix-socket /var/run/control.unit.sock http://localhost/$2)
    RET_BODY=$(echo $RET | /bin/sed '$ s/...$//')
    RET_STATUS=$(echo $RET | /usr/bin/tail -c 4)
    if [ "$RET_STATUS" -ne "200" ]; then
        echo "$0: Error: HTTP response status code is '$RET_STATUS'"
        echo "$RET_BODY"
        return 1
    else
        echo "$0: OK: HTTP response status code is '$RET_STATUS'"
        echo "$RET_BODY"
    fi
    return 0
}

get_env()
{
  echo "" | awk -v "key=$1" -v "fallback=$2" '{
    if (key in ENVIRON) {
      print ENVIRON[key]
    } else {
      print fallback
    }
  }'
}

# Change to the working directory.
cd /tmp

# Ensure we clean up correctly.
trap "rm -f key.pem cert.pem fullchain.pem unit-config.json" EXIT

tls_status="$(get_env "nginx.tls" "enabled" | tr '[:upper:]' '[:lower:]')"
tls_certificate="$(get_env "nginx.app.certificate" "localhost")"

# Generate and store the TLS certificate.
if [ "$tls_status" = "enabled" ]; then
  # Generate certificate.
  openssl req \
    -x509 \
    -newkey rsa:4096 \
    -keyout key.pem \
    -out cert.pem \
    -days 365 \
    -nodes \
    -subj "/CN=localhost"

  # Join them into a chain.
  cat key.pem cert.pem > fullchain.pem

  # Write the certificate.
  curl_put fullchain.pem "certificates/$tls_certificate"
fi

# Might need to set https://unit.nginx.org/configuration/#configuration-php-options

# Build the application JSON.
# shellcheck disable=SC2016
echo '
{
  "listeners": {
    "*:80": {
      "pass": "routes"
    },
    "*:443": {
      "pass": "routes",
      "tls": {
        "certificate": ""
      }
    }
  },
  "routes": [],
  "applications": {
    "app": {
      "type": "php"
    }
  }
}' | jq \
  --arg "tls_status" "$tls_status" \
  --arg "tls_certificate" "$tls_certificate" \
  --arg "root" "$(get_env "nginx.app.root" "/srv/public")" \
  --arg "script" "$(get_env "nginx.app.script" "index.php")" \
  --arg "workdir" "$(get_env "nginx.app.working_directory" "/srv")" \
  --arg "user" "$(get_env "nginx.app.user" "app")" \
  --arg "group" "$(get_env "nginx.app.group" "app")" \
  --arg "match_uri" "$(get_env "nginx.match_uri" "*.php,*.php/*")" \
  '
    .applications.app += {
      "targets": {
        "direct": {
          "root": $root
        },
        "catchall": {
          "root": $root,
          "script": $script
        }
      },
      "working_directory": $workdir,
      "group": $group,
      "user": $user
    }
    | if $tls_status == "enabled" then
        .listeners["*:443"].tls.certificate = $tls_certificate
      else
        del(.listeners["*:443"])
      end
    | . + {
        "routes": [
          {
            "match": {
              "uri": ($match_uri | split(","))
            },
            "action": {
              "pass": "applications/app/direct"
            }
          },
          {
            "action": {
              "share": ($root + "$uri"),
              "fallback": {
                "pass": "applications/app"
              }
            }
          }
        ]
      }
  ' | tee  unit-config.json

# Write the config.
curl_put unit-config.json "config"
