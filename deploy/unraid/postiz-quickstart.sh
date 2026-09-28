#!/usr/bin/env bash
# One-shot Postiz installer for Unraid.
#
# Downloads everything it needs and installs Postiz into /mnt/user/appdata/postiz.
# No git clone required — just this one file.
#
# Usage (Unraid: Tools > Terminal):
#   curl -fsSL https://raw.githubusercontent.com/jayvenco/postiz/main/deploy/unraid/postiz-quickstart.sh -o postiz-quickstart.sh
#   chmod +x postiz-quickstart.sh
#   ./postiz-quickstart.sh
#
# Safe to re-run: it refreshes the compose file and Temporal config but never
# overwrites an existing .env or any data already in APPDATA_DIR/data.

set -euo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/jayvenco/postiz/main"
APPDATA_DIR="${APPDATA_DIR:-/mnt/user/appdata/postiz}"

echo "==> Installing into $APPDATA_DIR"
mkdir -p "$APPDATA_DIR"/{data/postgres,data/redis,data/temporal-postgres,data/temporal-elasticsearch,config,uploads,dynamicconfig}

echo "==> Downloading compose file and Temporal config"
curl -fsSL "$REPO_RAW_BASE/deploy/unraid/docker-compose.yaml" -o "$APPDATA_DIR/docker-compose.yaml"
curl -fsSL "$REPO_RAW_BASE/dynamicconfig/development-sql.yaml" -o "$APPDATA_DIR/dynamicconfig/development-sql.yaml"
curl -fsSL "$REPO_RAW_BASE/dynamicconfig/development-cass.yaml" -o "$APPDATA_DIR/dynamicconfig/development-cass.yaml"

if [ ! -f "$APPDATA_DIR/.env" ]; then
  echo "==> No .env found, downloading template and generating secrets"
  curl -fsSL "$REPO_RAW_BASE/deploy/unraid/.env.example" -o "$APPDATA_DIR/.env"

  # Best-effort guess at the LAN IP this box is reachable on; falls back to
  # localhost if detection fails. Edit $APPDATA_DIR/.env afterwards if this
  # picked the wrong interface, or if you're putting Postiz behind a domain.
  DETECTED_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
  HOST_IP="${DETECTED_IP:-localhost}"

  JWT_SECRET="$(openssl rand -hex 32)"
  POSTGRES_PASSWORD="$(openssl rand -hex 16)"

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
