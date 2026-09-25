# Deploying Postiz on Unraid

This folder holds a self-contained docker-compose stack for running this fork of Postiz
on an Unraid server. It uses the official pre-built image
(`ghcr.io/gitroomhq/postiz-app:latest`) — no build step needed. If you start making your
own code changes to this fork and need those changes running in production, see
"Building your own image" below instead.

## First-time install

On the Unraid server (Tools > Terminal, or SSH):

```bash
git clone https://github.com/jayvenco/postiz.git /mnt/user/appdata/postiz-src
cd /mnt/user/appdata/postiz-src/deploy/unraid
cp .env.example .env
nano .env   # fill in JWT_SECRET (openssl rand -hex 32), POSTGRES_PASSWORD, and your URLs
./install.sh
```

Postiz will be reachable at `http://<unraid-ip>:4007` (or whatever you set `FRONTEND_URL`
to in `.env`). First boot takes a minute or two while Temporal and the backend finish
starting.

Ports used: `4007` (Postiz web UI), `7233` (Temporal, internal), `8080` (Temporal UI,
optional — helpful for debugging scheduled posts).

## Updating

```bash
cd /mnt/user/appdata/postiz-src
git pull
cd deploy/unraid
./install.sh
```

This pulls the newest `postiz-app:latest` image and recreates the containers. Your
database, uploads, and Temporal state live in named Docker volumes and are untouched.

## Building your own image

Once you start committing your own changes to this fork, `ghcr.io/gitroomhq/postiz-app:latest`
will no longer reflect what's in `origin/main` of your fork. To run your own build instead:

```bash
cd /mnt/user/appdata/postiz-src
docker build --target dist -f Dockerfile.dev -t postiz-app:local .
```

Then in `docker-compose.yaml`, change the `postiz` service's `image:` line from
`ghcr.io/gitroomhq/postiz-app:latest` to `postiz-app:local`, and re-run `./install.sh`.
