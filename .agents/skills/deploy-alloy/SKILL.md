---
name: deploy-alloy
description: Deploy or troubleshoot the per-host Grafana Alloy collector in taiidani's monitoring repo using Uncloud (`uc`). Use when asked to deploy Alloy, change its config, or debug missing logs/metrics/traces in Grafana Cloud.
---

# Deploying Alloy

Alloy runs on every host (`deploy.mode: global`) and ships logs, metrics and traces to Grafana Cloud. It is deployed with [Uncloud](https://uncloud.run/docs/) (`uc` CLI) from `alloy/`. `mise` is **not** used for deploying; it only provides tooling (`fnox`, `terraform`) via the root `mise.toml`.

Secrets (1Password/fnox) are covered by the `manage-secrets` skill.

## Deploying

```bash
cd alloy
uc deploy
```

`uc deploy` reads `compose.yml`, prints a plan, asks for confirmation, and performs rolling updates. Always deploy from inside `alloy/`: Uncloud derives the project name from the directory, and the OBI sidecar sends traces to `alloy.internal:4317`, which relies on the service being named `alloy`.

Useful follow-ups:

```bash
uc ls                    # list services
uc inspect alloy         # status/details
uc logs alloy -f         # stream logs
```

## What's in `alloy/`

- `config.alloy` - the pipeline: container logs (Loki), OTLP traces/metrics receiver, built-in node (`prometheus.exporter.unix`) and cAdvisor exporters, all remote-written to Grafana Cloud.
- `compose.yml` - Alloy plus the `ebpf-autoinstrumenter` (OBI) sidecar.
- `obi-config.yml` - which containers OBI instruments.
- `fnox.toml` - the `GRAFANA_CLOUD_*` secrets from the `Grafana Cloud` 1Password item.

Validate config changes before deploying:

```bash
docker run --rm -e GRAFANA_CLOUD_TOKEN=x -e GRAFANA_CLOUD_PROM_URL=https://x \
  -e GRAFANA_CLOUD_PROM_USER=1 -e GRAFANA_CLOUD_LOKI_URL=https://x \
  -e GRAFANA_CLOUD_LOKI_USER=1 -e GRAFANA_CLOUD_TEMPO_URL=x:443 \
  -e GRAFANA_CLOUD_TEMPO_USER=1 -v $PWD/alloy/config.alloy:/c.alloy:ro \
  grafana/alloy:v1.17.1 validate /c.alloy
```

## Gotchas

- **Do not bind-mount `/` or `/var/run`** into the Alloy container. They contain sockets, which breaks Uncloud's config injection at deploy time (`inject configs ... openat run/docker.sock`).
- **cAdvisor needs the containerd socket** (`/run/containerd/containerd.sock`) mounted, or container series lose their `name` label.
- **Hostname:** `constants.hostname` returns the container's hostname, so the real one is read from the mounted `/etc/hostname` and used for the `host` and `instance` labels.
- **`pid: host` + `privileged`** are required for the built-in node exporter (host `/proc` and root fs via `/proc/1/root`) and cAdvisor.
- **Free tier limit:** 10k active series. Check usage in Grafana Cloud after changing the relabel rules.
- **Alloy debug UI:** `http://<host>:12345` shows component health.
