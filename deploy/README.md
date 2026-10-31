# Running ComeOver on UmbrelOS over Tailscale

The relay is a small Node + Socket.IO service. On UmbrelOS the recommended setup is the packaged
community app in [`umbrel/`](umbrel/README.md): it adds a dashboard, an Umbrel app icon, a proxy on
port `8788`, and a direct client port on `8787`.

This page covers the whole setup, including the plain Docker Compose path and Tailscale.

```
phone / tablet ── Tailscale ──┐
                              ├──> UmbrelOS :8787 (ComeOver relay)
home TV ─────── LAN ──────────┘
```

## Option A: install the Umbrel app (recommended)

See [umbrel/README.md](umbrel/README.md). In short:

1. Publish `server/` as a multi-arch image (the included GitHub Actions workflow does this).
2. Push `deploy/umbrel` as a community app-store repository.
3. Add that repository in **App Store → ⋯ → Community App Stores**.
4. Install **ComeOver** and open its dashboard.

Ports after install:

| Port | What | Auth |
| --- | --- | --- |
| `8788` | Relay dashboard, through Umbrel's app proxy | Umbrel login |
| `8787` | REST + Socket.IO + invite pages for companion apps | Room tokens only |
| `8240` | Tailscale app UI, if installed | Tailscale |

The dashboard prints the direct `8787` address derived from the hostname you used to open it.

## Option B: plain Docker Compose

For a quick test without installing the app package, copy this repository to the Umbrel box and
run:

```bash
cd comeover/deploy
docker compose up -d --build
curl http://localhost:8787/healthz
# {"ok":true,"rooms":0,"uptime":...,"version":"0.1.0"}
```

The compose file publishes `8787` on the host. If the box has no Compose plugin, build and run the
same image directly:

```bash
cd comeover
docker build -t comeover-relay:local server
docker run -d \
  --name comeover-relay \
  --restart unless-stopped \
  -p 8787:8787 \
  -e PORT=8787 \
  -e HOST=0.0.0.0 \
  comeover-relay:local
```

There is no separate database or volume: rooms are in memory and expire after six hours.

## 1. Put the Umbrel on the tailnet

Install **Tailscale** from the Umbrel App Store and sign in. The official Umbrel Tailscale package
runs in host-network mode with a TUN device, so the relay's host port is reachable on the tailnet
without a sidecar.

The Umbrel may not have a host `tailscale` CLI. Use the Tailscale app UI on port `8240`, or run
commands inside its container (usually `tailscale_web_1`):

```bash
sudo docker exec tailscale_web_1 tailscale status
sudo docker exec tailscale_web_1 tailscale ip -4
```

Pick one address for the relay:

- `http://umbrel:8787` (MagicDNS short name, if enabled)
- `http://umbrel.<your-tailnet>.ts.net:8787` (MagicDNS FQDN)
- `http://100.x.y.z:8787` (Tailscale IP, most reliable fallback)

Test from a phone that is connected to Tailscale:

```
http://100.x.y.z:8787/healthz
```

## 2. Build the app with the tailnet URL

```bash
cd app
flutter build apk --release \
  --dart-define=COMEOVER_SERVER=http://100.x.y.z:8787 \
  --dart-define=COMEOVER_PUBLIC_URL=http://100.x.y.z:8787
```

`COMEOVER_PUBLIC_URL` is the base of the invite links. If it says `localhost`, a guest will open a
link that only works on their own device. The app also has **Settings → Relay**, so you can change
the address on a device without rebuilding.

For a physical Android device, allow cleartext HTTP (already enabled for self-hosted relays in
this app) and use the tailnet address above. For iOS, the ATS exception is already configured.

## 3. Let a guest in

A guest needs a network path to the Umbrel, because they are usually on cellular while travelling.
Recommended for one-off guests: **share the Umbrel node** from the Tailscale admin console
(**Machines → Umbrel → Share**). The guest installs Tailscale, accepts the share, and can reach the
Umbrel without joining your whole tailnet.

If you invite them into the tailnet directly, use a tag/ACL that only exposes TCP `8787` (and
`8788` if they need the dashboard) and nothing else.

Same-LAN guests can skip Tailscale entirely and use `http://<umbrel-lan-ip>:8787`.

## 4. Optional: HTTPS inside the tailnet

Plain HTTP is fine for the native apps. The web build is the exception: browsers only expose
geolocation on HTTPS or localhost.

Tailscale Serve gives the relay a trusted certificate on the tailnet. Because the Tailscale
container uses host networking, `127.0.0.1` is the host loopback:

```bash
sudo docker exec tailscale_web_1 tailscale serve --bg http://127.0.0.1:8787
sudo docker exec tailscale_web_1 tailscale serve status
```

Then use `https://umbrel.<your-tailnet>.ts.net` (no port) as both `COMEOVER_SERVER` and
`COMEOVER_PUBLIC_URL`.

Tailscale Funnel is the public, no-Tailscale version:

```bash
sudo docker exec tailscale_web_1 tailscale funnel --bg http://127.0.0.1:8787
```

Funnel exposes the relay to the public internet on an HTTPS URL. The relay has no accounts beyond
room codes, so treat Funnel as a temporary/demo option and turn it off afterwards:

```bash
sudo docker exec tailscale_web_1 tailscale funnel --bg off
```

## TVs

Fire TV and most Android TV boxes do not have a Tailscale client. Keep the TV on the home LAN and
point **Settings → Relay** at `http://<umbrel-lan-ip>:8787` instead. The TV can still join the same
room as long as it can reach the relay over the LAN; the guest's phone reaches it over the
tailnet.

The host phone should stay on the tailnet URL so the invite links it shares are reachable by the
guest. Both devices meet in the same relay room.

## Tailscale subnet routers

A subnet router lets tailnet devices reach a LAN CIDR through one node. It is useful for devices
that cannot run Tailscale, but ComeOver itself does not need it: the relay is on the Umbrel, which
is already a tailnet node, and a TV on the LAN reaches the Umbrel by its LAN IP.

See [umbrel/README.md#tailscale-subnet-routers-exit-nodes-and-why-comeover-does-not-need-them](umbrel/README.md#tailscale-subnet-routers-exit-nodes-and-why-comeover-does-not-need-them)
for the full explanation, including route approval, `--accept-routes`, IP forwarding, and the
difference from an exit node.

## Restart behaviour

Rooms are in memory. Restarting the app/container or the Umbrel drops active rooms. The relay
restarts automatically with Docker unless you remove it.
