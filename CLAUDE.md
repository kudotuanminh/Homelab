# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Subagents

Spawn subagents to isolate context, parallelize independent work, or offload bulk mechanical tasks. Don't spawn when the parent needs the reasoning, when synthesis requires holding things together, or when spawn overhead dominates.

Pick the cheapest model that can do the subtask well:

- Haiku: bulk mechanical work, no judgment
- Sonnet: scoped research, code exploration, in-scope synthesis
- Opus: subtasks needing real planning or tradeoffs

If a subagent realizes it needs a higher tier than itself, return to the parent.

Parent owns final output and cross-spawn synthesis. User instructions override.

## Preferred Tools

### Data Fetching

1. **WebFetch**: free, text-only, works on public pages that don't block bots.
2. **agent-browser CLI**: free, local Rust CLI + Chrome via CDP. For dynamic pages or auth walls that WebFetch can't handle. Returns the accessibility tree with element refs (@e1, @e2). ~82% fewer tokens than screenshot-based tools. Install: `npm i -g agent-browser && agent-browser install`. Use `snapshot` for AI-friendly DOM state, element refs for interaction.
3. **Notice recurring fetch patterns and propose wrapping them as dedicated tools.** When the same fetch/parse logic comes up more than once, suggest wrapping it as a named tool (e.g. a skill file or a .py script that calls `agent-browser` with the snapshot and extraction steps baked in for that source). Add the entry to `## Dedicated Tools` below and reference it by name on future calls.

### PDF Files

Use 'pdftotext', not the 'Read' tool. Use 'Read' only when the user directly asks to analyze images or charts inside the document. Read loads PDFs as images.

## Dedicated Tools

<!-- List project-specific tools here. For each, link to its skill or script file (e.g. `tools/reddit_fetch.py`). The orchestration logic lives in those files, not here. -->

## What this repo is

An infrastructure-as-config homelab: each subdirectory of `Docker/` is an independently-deployed Docker Compose stack. No build system, test suite, or lint — changes validated by running `docker compose up -d` in the affected stack directory. `etc/` holds host-level files (motd) and `node-windows/` is an unrelated Windows service wrapper for the `demergi` DPI proxy.

## Common operations

All compose commands run from inside the relevant `Docker/<stack>/` directory:

```bash
docker compose up -d            # start/recreate
docker compose pull && docker compose up -d   # upgrade after bumping image tag
docker compose logs -f <svc>
docker compose down             # stop (data in ./data persists)
```

Caddy config reloads without restarting container via `Docker/reverse-proxy.caddy/reload.sh` — runs `caddy fmt --overwrite` then `caddy reload` inside the running container. Edit `config/Caddyfile` then run the script.

## Cross-stack conventions

These conventions are repo-wide — follow when adding a new stack:

- **Directory naming**: `<number>.<name>` is the **legacy** layout (the number is the third octet of a fixed `172.18.N.0/24` subnet). All numbered stacks slated for migration to `<category>.<name>`. New work goes in `<category>.<name>` (`monitoring.*`, `zero-trust.*`, `reverse-proxy.*`, `password.*`); don't add new numbered stacks. When migrating, drop the hard-coded subnet — new style uses external named networks and lets Docker pick CIDRs.
- **Secrets**: every stack needing secrets reads them from a sibling `.env` (gitignored — `.gitignore` excludes `*/.env`). Required vars use `${VAR:?error}` so compose fails fast if missing; defaults use `${VAR:-fallback}`. Never inline a secret in `docker-compose.yml`.
- **Config templates**: when a config file contains secrets or host-specific values, commit a `*.example` next to it (see `Caddyfile.example`, `prometheus.yml.example`) and gitignore the real file. The example uses `${VAR}` placeholders that the user substitutes by hand or via compose env interpolation.
- **Image pinning**: every `image:` is pinned to an exact tag (e.g. `caddy:2.11.2`, `fosrl/pangolin:ee-1.18.3`). Don't introduce `latest` — upgrades are intentional commits that bump the tag.
- **Networks**: legacy numbered stacks define their own bridge with a hard-coded `172.18.N.0/24` subnet. `<category>.<name>` stacks instead join shared external networks — `proxy` for anything Caddy/Pangolin should reverse-proxy, `monitoring_network` for anything vmagent should scrape — and declare them without `ipam`/CIDR (`external: true`, name only). Both networks must already exist on the host (`docker network create proxy` / `monitoring_network`) before bringing those stacks up.
- **Logging**: long-running services set `logging.driver` (`json-file` or `local`) with `max-size: 200m` to bound disk usage. Match this when adding services.

## Reverse-proxy architecture

Two reverse proxies coexist by design:

- **`reverse-proxy.caddy`** — the primary edge proxy. Uses a custom `Dockerfile` that rebuilds Caddy with the `caddy-dns/cloudflare` plugin so it can solve DNS-01 challenges against the Cloudflare API (creds in `.env`). It listens on `:443` and reverse-proxies to backends on the `proxy` network. The `Caddyfile` is one site block per domain; new public services usually mean a new block + adding the service to the `proxy` network.
- **`zero-trust.pangolin`** — Pangolin + Gerbil (WireGuard) + Traefik bundle that exposes remote sites without poking holes in the firewall at the target site. It binds host `:80`, `:443`, and WireGuard UDP ports, so it cannot coexist with Caddy on the *same* host on those ports — pangolin runs on a different host. `zero-trust.pangolin-newt` is the client side: a tiny tunnel container that joins the local `proxy` network and registers back to `pangolin.minhnt.net`.

`Docker/7.adguardhome/get-cert-from-caddy.sh` and `get-cert-from-nginx.sh` are one-off helpers that copy Let's Encrypt cert/key out of Caddy's (or the old nginx-proxy-manager's) data dir into AdGuard's letsencrypt dir, since AdGuard reads certs from disk rather than negotiating its own. Re-run after a cert renewal if AdGuard's HTTPS breaks.

## Monitoring pipeline

Two-stack pipeline split between the collector and the storage/UI host:

- **`Docker/monitoring.vmagent/`** — collector side (`6.vmagent` is the older standalone copy — prefer the `monitoring.*` one for new work). Runs four containers that expose Prometheus metrics: `vmagent` itself, `node-exporter` (host), `cadvisor` (containers), and `endlessh` (SSH tarpit). `vmagent` scrapes them per `config/prometheus.yml` and remote-writes to the central VictoriaMetrics endpoint (`VM_ENDPOINT` in `.env`, typically a Caddy-fronted HTTPS URL like `https://vm.minhnt.net/api/v1/write`).
- **`Docker/monitoring.grafana-stack/`** — storage + UI side. Three services: `victoriametrics` (metrics TSDB, `:8428`), `victorialogs` (log storage, `:9428`), and `grafana` (dashboards, `:3000`). No host port bindings — services talk to each other on `monitoring_network` and are exposed externally via Caddy on the `proxy` network. Grafana datasources are auto-provisioned from `config/grafana/provisioning/datasources/datasources.yml` (gitignored; copy from the `.example` next to it), and opinionated non-secret Grafana settings live in `config/grafana/grafana.ini`. The VM-specific datasource plugins (`victoriametrics-metrics-datasource`, `victoriametrics-logs-datasource`) are pulled in via `GF_INSTALL_PLUGINS` at startup.

When adding a new service that should be scraped, add its `host:port` to the appropriate `job_name` in `monitoring.vmagent/config/prometheus.yml` and ensure it's on `monitoring_network`. If the new service lives on the same host as the grafana-stack, it can be scraped directly by container name; otherwise it remote-writes through `VM_ENDPOINT`.

## Bumping a service version

Recent commits (`Update caddy, vaultwarden`, `Update Uptime Kuma`) show the workflow: edit the `image:` tag in `docker-compose.yml`, commit with a short `Update <service>` message, then `docker compose pull && docker compose up -d` in that stack directory. Don't bundle unrelated upgrades into one commit.