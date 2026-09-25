#!/usr/bin/env bash
# Installs / updates Postiz on this Unraid server.
#
# Usage (run on the Unraid box, e.g. via Tools > Terminal):
#   git clone https://github.com/jayvenco/postiz.git /mnt/user/appdata/postiz-src
#   cd /mnt/user/appdata/postiz-src/deploy/unraid
#   cp .env.example .env && nano .env   # fill in JWT_SECRET, POSTGRES_PASSWORD, URLs
#   ./install.sh
#
# Re-running this script later (e.g. after `git pull`) pulls the latest
# postiz image and recreates the stack without touching your data volumes.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -f .env ]; then
  echo "Missing .env — copy .env.example to .env and fill in real values first." >&2
  exit 1
fi

echo "==> Pulling latest images"
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

echo
echo "Done. Postiz should be reachable at the FRONTEND_URL set in .env (default http://<unraid-ip>:4007)."
echo "First load can take a minute while the backend finishes booting and connecting to Temporal."
