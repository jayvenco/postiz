#!/usr/bin/env bash
# Prepares /mnt/user/appdata/postiz for Postiz on Unraid. Does NOT start anything.
#
# Creates the folder structure, downloads docker-compose.yaml and the Temporal
# config, and creates .env with generated secrets (only if no .env exists yet).
# Afterwards, start the stack yourself:
#   cd /mnt/user/appdata/postiz && docker compose up -d

set -euo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/jayvenco/postiz/main"
APPDATA_DIR="${APPDATA_DIR:-/mnt/user/appdata/postiz}"

echo "==> Preparing $APPDATA_DIR"
mkdir -p "$APPDATA_DIR"/{data/postgres,data/redis,data/temporal-postgres,data/temporal-elasticsearch,config,uploads,dynamicconfig}

echo "==> Downloading compose file and Temporal config"
curl -fsSL "$REPO_RAW_BASE/deploy/unraid/docker-compose.yaml" -o "$APPDATA_DIR/docker-compose.yaml"
curl -fsSL "$REPO_RAW_BASE/dynamicconfig/development-sql.yaml" -o "$APPDATA_DIR/dynamicconfig/development-sql.yaml"
curl -fsSL "$REPO_RAW_BASE/dynamicconfig/development-cass.yaml" -o "$APPDATA_DIR/dynamicconfig/development-cass.yaml"

if [ -f "$APPDATA_DIR/.env" ]; then
  echo "==> Existing .env found, leaving it untouched"
else
  echo "==> Creating .env with generated secrets"
  curl -fsSL "$REPO_RAW_BASE/deploy/unraid/.env.example" -o "$APPDATA_DIR/.env"

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

  echo "    Host IP used for the URLs: ${HOST_IP}"
fi

echo
echo "Prepared. Review $APPDATA_DIR/.env (URLs, optional API keys), then start with:"
echo "  cd $APPDATA_DIR && docker compose up -d"
