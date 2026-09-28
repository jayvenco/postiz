#!/usr/bin/env bash
# Rotates JWT_SECRET and the Postgres password for an already-deployed Postiz
# stack on Unraid (installed via postiz-quickstart.sh / install.sh).
#
# What it does:
#   1. Generates a new JWT_SECRET and Postgres password.
#   2. Changes the password of the live Postgres user (ALTER USER), so the
#      database itself, not just .env, is updated.
#   3. Writes both new values into .env (JWT_SECRET, POSTGRES_PASSWORD,
#      DATABASE_URL).
#   4. Recreates the postiz container so it picks up the new values.
#
# Usage (Unraid: Tools > Terminal):
#   curl -fsSL https://raw.githubusercontent.com/jayvenco/postiz/main/deploy/unraid/rotate-secrets.sh | bash
#
# Note: rotating JWT_SECRET invalidates every existing logged-in session —
# everyone (including you) has to log in again afterwards. That's expected.

set -euo pipefail

APPDATA_DIR="${APPDATA_DIR:-/mnt/user/appdata/postiz}"
ENV_FILE="$APPDATA_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env found at $ENV_FILE — is Postiz installed? Run postiz-quickstart.sh first." >&2
  exit 1
fi

if ! docker inspect postiz-postgres >/dev/null 2>&1; then
  echo "Container postiz-postgres is not running — start the stack before rotating secrets." >&2
  exit 1
fi

get_env_value() {
  local key="$1"
  grep -oP "(?<=^${key}=\").*(?=\"\$)" "$ENV_FILE" || true
}

POSTGRES_USER="$(get_env_value POSTGRES_USER)"
POSTGRES_DB="$(get_env_value POSTGRES_DB)"

if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_DB" ]; then
  echo "Could not read POSTGRES_USER / POSTGRES_DB from $ENV_FILE — aborting." >&2
  exit 1
fi

NEW_JWT_SECRET="$(openssl rand -hex 32)"
NEW_POSTGRES_PASSWORD="$(openssl rand -hex 16)"

echo "==> Changing password for Postgres user '$POSTGRES_USER' inside postiz-postgres"
docker exec -i postiz-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 \
  -c "ALTER USER \"$POSTGRES_USER\" WITH PASSWORD '$NEW_POSTGRES_PASSWORD';"

echo "==> Writing new secrets into $ENV_FILE"
cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d%H%M%S)"
sed -i \
  -e "s#^JWT_SECRET=.*#JWT_SECRET=\"${NEW_JWT_SECRET}\"#" \
  -e "s#^POSTGRES_PASSWORD=.*#POSTGRES_PASSWORD=\"${NEW_POSTGRES_PASSWORD}\"#" \
  -e "s#^DATABASE_URL=.*#DATABASE_URL=\"postgresql://${POSTGRES_USER}:${NEW_POSTGRES_PASSWORD}@postiz-postgres:5432/${POSTGRES_DB}\"#" \
  "$ENV_FILE"

echo "==> Recreating the postiz container with the new secrets"
cd "$APPDATA_DIR"
docker compose up -d --force-recreate postiz

echo
echo "Done. JWT_SECRET and the Postgres password have been rotated."
echo "A backup of the previous .env was saved next to it (.env.bak.<timestamp>)."
echo "Everyone, including you, will need to log in again — the old JWT_SECRET no longer works."
