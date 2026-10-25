---
name: deploy-alloy
description: Deploy or troubleshoot the Grafana Alloy collector in taiidani's monitoring repo, on `web` with Uncloud (`uc`) and on `obsidian` with `mise bootstrap remote`. Use when asked to deploy Alloy, change its config, or debug missing logs/metrics/traces in Grafana Cloud.
---

# Deploying Alloy

Alloy ships logs, metrics and traces to Grafana Cloud. One set of config files, split by purpose, lives in `alloy/config/` and is deployed two ways, both from `alloy/`:

| Host | Method | Directory |
| --- | --- | --- |
| `web` (Uncloud cluster, Docker) | `uc deploy`, Alloy as a container | `compose.yml` |
| `obsidian` (Proxmox, not in the cluster) | `mise bootstrap remote`, Alloy as a systemd service | `mise.toml`, `mise.obsidian.toml` |

Secrets (1Password/fnox) are covered by the `manage-secrets` skill.

## Config layout (`alloy/config/`)

Alloy loads every `*.alloy` file in a directory as one configuration, and files reference each other's components, so a host needs a matching destination for each source it loads.

- `hostname.alloy` - the real hostname for `host`/`instance` labels. Reads `ALLOY_HOSTNAME_FILE` (default `/etc/hostname`).
- `host-metrics.alloy` - node exporter. Reads `ALLOY_ROOTFS_PATH` (default `/`).
- `container-metrics.alloy`, `docker-logs.alloy`, `otlp.alloy` - Docker hosts (web).
- `journal-logs.alloy` - systemd journal (obsidian).
- `destination-metrics.alloy`, `destination-logs.alloy`, `destination-traces.alloy` - Grafana Cloud endpoints.

Validate after any change, for each host's file set (copy them into one directory and validate that directory):

```bash
d=$(mktemp -d); cp alloy/config/{hostname,host-metrics,destination-metrics,destination-logs,journal-logs}.alloy $d/
docker run --rm -e GRAFANA_CLOUD_TOKEN=x -e GRAFANA_CLOUD_PROM_URL=https://x -e GRAFANA_CLOUD_PROM_USER=1 \
  -e GRAFANA_CLOUD_LOKI_URL=https://x -e GRAFANA_CLOUD_LOKI_USER=1 -e GRAFANA_CLOUD_TEMPO_URL=x:443 \
  -e GRAFANA_CLOUD_TEMPO_USER=1 -v $d:/c:ro grafana/alloy:v1.21.2 validate /c
```

An empty or wrong directory also exits 0, so check the printed file list and expect a non-zero exit when a referenced component is missing.

## web (Uncloud)

```bash
cd alloy
uc deploy
```

`uc deploy` prints a plan and asks for confirmation. Always deploy from inside `alloy/`: Uncloud derives the project name from the directory, and the OBI sidecar sends traces to `alloy.internal:4317`, which relies on the service being named `alloy`.

- `compose.yml` - Alloy plus the `ebpf-autoinstrumenter` (OBI) sidecar. The shared files are injected from `./config` into `/etc/alloy/`.
- `empty.alloy` - injected as `/etc/alloy/config.alloy` to replace the image's default, which would otherwise be loaded with the rest.
- `obi-config.yml` - which containers OBI instruments.
- `fnox.toml` - the `GRAFANA_CLOUD_*` secrets.

Gotchas:
- Config targets must be in an **existing** directory in the image (copy into a missing one fails), so `/etc/alloy/`, not `/etc/alloy/conf.d/`.
- **Do not bind-mount `/` or `/var/run`** into the Alloy container: they contain sockets, which breaks config injection at deploy time (`inject configs ... openat run/docker.sock`).
- cAdvisor needs the containerd socket (`/run/containerd/containerd.sock`) mounted, or container series lose their `name` label.
- `constants.hostname` is the container's hostname, so the real one comes from the mounted `/etc/hostname` via `ALLOY_HOSTNAME_FILE`.
- `pid: host` + `privileged` are required for the built-in node exporter (`ALLOY_ROOTFS_PATH=/proc/1/root`) and cAdvisor.

Useful follow-ups: `uc ls`, `uc inspect alloy`, `uc logs alloy -f`.

## obsidian (Mise)

```bash
mise bootstrap remote obsidian --dry-run --prompt-secrets
mise bootstrap remote obsidian --prompt-secrets
```

Defined in `alloy/` (`mise.toml` shared base, `mise.obsidian.toml` overlay) and registered in the root `mise.toml`, which excludes the Uncloud-only files when sending the directory. See `alloy/README.md`.

- `--prompt-secrets` supplies the token; a remote run does not copy the local environment, and Mise's fnox integration only feeds tasks.
- The workstation `mise` must be an official release (installer script), not a distro package, or the uploaded binary can't run on the host.
- mise never deletes files: retired config files need a `state = "absent"` entry, or they'd define components twice.
- Apt key fingerprints must be the **primary** key, not a subkey.

## Both

- Free tier limit: 10k active series. Check usage in Grafana Cloud after changing relabel rules.
- Alloy debug UI: `http://<host>:12345` on web; localhost-only on obsidian (`ssh -L 12345:localhost:12345 root@obsidian`).
