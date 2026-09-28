# Deploying Postiz on Unraid

Self-contained docker-compose stack for running this fork of Postiz on an Unraid server,
installed the Unraid way: everything (compose file, `.env`, Temporal config, and all
persistent data) lives under `/mnt/user/appdata/postiz`, so it shows up in the Unraid
Docker tab and gets picked up by appdata backup plugins (e.g. CA Backup / Restore).

Uses the official pre-built image (`ghcr.io/gitroomhq/postiz-app:latest`) — no build step
needed. If you start making your own code changes to this fork and need those changes
running in production, see "Building your own image" below instead.

## First-time install (one command, no git clone)

On the Unraid server (Tools > Terminal, or SSH):

```bash
curl -fsSL https://raw.githubusercontent.com/jayvenco/postiz/main/deploy/unraid/postiz-quickstart.sh | bash
```

This downloads what it needs directly and does not require cloning the repo. If you'd
rather review the script before running it (recommended for anything you pipe into `bash`):

```bash
curl -fsSL https://raw.githubusercontent.com/jayvenco/postiz/main/deploy/unraid/postiz-quickstart.sh -o postiz-quickstart.sh
less postiz-quickstart.sh   # read it
chmod +x postiz-quickstart.sh
./postiz-quickstart.sh
```

### Alternative: install from a full repo checkout

Useful once you're customizing the fork and want deploy files to match a specific commit:

```bash
git clone https://github.com/jayvenco/postiz.git /tmp/postiz-src
cd /tmp/postiz-src/deploy/unraid
./install.sh
```

Either way, the script:
- creates `/mnt/user/appdata/postiz` with `data/`, `config/`, `uploads/`, `dynamicconfig/`
- generates a random `JWT_SECRET` and Postgres password into `.env` if one doesn't exist yet
- guesses this server's LAN IP for `MAIN_URL` / `FRONTEND_URL` / `NEXT_PUBLIC_BACKEND_URL`
- pulls the images and starts the stack

Check `/mnt/user/appdata/postiz/.env` afterwards — if the detected IP is wrong, or if
you're putting Postiz behind a reverse proxy with a real domain, edit the three URL lines
there and run `docker compose up -d` again from that folder.

Postiz will be reachable at `http://<unraid-ip>:4007` (or whatever `FRONTEND_URL` ends up
set to). First boot takes a minute or two while Temporal and the backend finish starting.

Ports used: `4007` (Postiz web UI), `7233` (Temporal, internal), `8080` (Temporal UI,
optional — helpful for debugging scheduled posts).

## Updating

Re-run the same one-liner — it refreshes the compose file and Temporal config but never
overwrites an existing `.env`, and your data stays in `/mnt/user/appdata/postiz/data`:

```bash
curl -fsSL https://raw.githubusercontent.com/jayvenco/postiz/main/deploy/unraid/postiz-quickstart.sh | bash
```

Or, for just a newer image without re-fetching anything:

```bash
cd /mnt/user/appdata/postiz
docker compose pull
docker compose up -d
```

## Building your own image

Once you start committing your own changes to this fork, `ghcr.io/gitroomhq/postiz-app:latest`
will no longer reflect what's in `origin/main` of your fork. To run your own build instead:

```bash
cd /tmp/postiz-src   # the full repo checkout, not deploy/unraid
docker build --target dist -f Dockerfile.dev -t postiz-app:local .
```

Then in `/mnt/user/appdata/postiz/docker-compose.yaml`, change the `postiz` service's
`image:` line from `ghcr.io/gitroomhq/postiz-app:latest` to `postiz-app:local`, and run
`docker compose up -d` again from `/mnt/user/appdata/postiz`.
