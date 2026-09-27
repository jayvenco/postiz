#!/usr/bin/env bash
# Installs Postiz on this Unraid server into /mnt/user/appdata/postiz.
#
# Usage (run on the Unraid box, e.g. via Tools > Terminal):
#   git clone https://github.com/jayvenco/postiz.git /tmp/postiz-src
#   cd /tmp/postiz-src/deploy/unraid
#   ./install.sh
#
# Everything the stack needs (compose file, .env, Temporal config, and all
# persistent data) is copied/created under APPDATA_DIR below. Once installed,
# the /tmp/postiz-src checkout used to run this script is no longer needed —
# all further management (start/stop/update) happens from APPDATA_DIR.
#
# Re-running this script later (e.g. after a fresh `git clone` of an updated
# fork) refreshes the compose file and Temporal config but never touches an
# existing .env or any data already in APPDATA_DIR/data.

set -euo pipefail

APPDATA_DIR="${APPDATA_DIR:-/mnt/user/appdata/postiz}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "==> Installing into $APPDATA_DIR"
mkdir -p "$APPDATA_DIR"/{data/postgres,data/redis,data/temporal-postgres,data/temporal-elasticsearch,config,uploads}

echo "==> Copying compose file and Temporal config"
cp "$SCRIPT_DIR/docker-compose.yaml" "$APPDATA_DIR/docker-compose.yaml"
rm -rf "$APPDATA_DIR/dynamicconfig"
cp -r "$REPO_ROOT/dynamicconfig" "$APPDATA_DIR/dynamicconfig"

if [ ! -f "$APPDATA_DIR/.env" ]; then
  echo "==> No .env found, creating one with generated secrets"

  # Best-effort guess at the LAN IP this box is reachable on; falls back to
  # localhost if detection fails. Edit $APPDATA_DIR/.env afterwards if this
  # picked the wrong interface, or if you're putting Postiz behind a domain.
  DETECTED_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
  HOST_IP="${DETECTED_IP:-localhost}"

  JWT_SECRET="$(openssl rand -hex 32)"
  POSTGRES_PASSWORD="$(openssl rand -hex 16)"

  cp "$SCRIPT_DIR/.env.example" "$APPDATA_DIR/.env"
  sed -i \
    -e "s#^JWT_SECRET=.*#JWT_SECRET=\"${JWT_SECRET}\"#" \
    -e "s#^POSTGRES_PASSWORD=.*#POSTGRES_PASSWORD=\"${POSTGRES_PASSWORD}\"#" \
    -e "s#^DATABASE_URL=.*#DATABASE_URL=\"postgresql://postiz-user:${POSTGRES_PASSWORD}@postiz-postgres:5432/postiz-db-local\"#" \
    -e "s#192\.168\.2\.200#${HOST_IP}#g" \
    "$APPDATA_DIR/.env"

  echo "    Generated JWT_SECRET and POSTGRES_PASSWORD."
  echo "    Guessed host IP: ${HOST_IP} (edit $APPDATA_DIR/.env if this is wrong,"
  echo "    or if you're putting Postiz behind a reverse proxy domain)."
else
  echo "==> Existing .env found in $APPDATA_DIR, leaving it untouched"
fi

cd "$APPDATA_DIR"

echo "==> Pulling images"
docker compose pull

echo "==> Starting stack"
docker compose up -d

echo "==> Waiting for Temporal to accept connections on :7233"
for i in $(seq 1 30); do
  if docker exec temporal-admin-tools tctl --address temporal:7233 cluster health >/dev/null 2>&1; then
    echo "Temporal is up."
    break
  fi
  sleep 4
done

echo "==> Current status"
docker compose ps

FRONTEND_URL="$(grep -oP '(?<=^FRONTEND_URL=").*(?="$)' "$APPDATA_DIR/.env" || true)"
echo
echo "Done. Postiz should be reachable at: ${FRONTEND_URL:-<see FRONTEND_URL in .env>}"
echo "First load can take a minute while the backend finishes booting and connecting to Temporal."
echo "Config lives in: $APPDATA_DIR (.env, docker-compose.yaml, data/)"
