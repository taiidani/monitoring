# Alloy

Alloy collects metrics, logs and traces and ships them to Grafana Cloud. One set
of config files, split by purpose (`config/`), is deployed two ways:

| Host | Method | Files |
| --- | --- | --- |
| `web` (Uncloud cluster, Docker) | `uc deploy`, Alloy plus the OBI sidecar as containers | `compose.yml`, `empty.alloy`, `obi-config.yml`, `fnox.toml` |
| `obsidian` (Proxmox, outside the cluster) | [`mise bootstrap remote`](https://mise.jdx.dev/bootstrap/remote.html), Alloy as a systemd service | `mise.toml` (shared base), `mise.obsidian.toml` (overlay) |

Hosts and their `mise_env` overlay are declared in the repo-root `mise.toml`,
which excludes the Uncloud-only files when sending this directory to a host.
Alloy loads every `*.alloy` file in a directory as one configuration.

## Alloy config files (`config/`)

| File | Signal | Used by |
| --- | --- | --- |
| `hostname.alloy` | real hostname for labels | all |
| `host-metrics.alloy` | node exporter | all |
| `destination-metrics.alloy` | Grafana Cloud Prometheus | all |
| `destination-logs.alloy` | Grafana Cloud Loki | all |
| `journal-logs.alloy` | systemd journal | obsidian |
| `container-metrics.alloy` | cAdvisor | web |
| `docker-logs.alloy` | Docker logs | web |
| `otlp.alloy` | OTLP receiver, trace/metric pipeline | web |
| `destination-traces.alloy` | Grafana Cloud Tempo | web |

Files reference each other's components, so a host needs the matching
destination files for every source it loads. Environment variables
`ALLOY_HOSTNAME_FILE` and `ALLOY_ROOTFS_PATH` let a containerised Alloy point at
the host's hostname file and root filesystem; natively they default to
`/etc/hostname` and `/`.

## Apply on obsidian (Mise)

```bash
mise bootstrap remote obsidian --dry-run --prompt-secrets   # preview
mise bootstrap remote obsidian --prompt-secrets             # apply
```

`--prompt-secrets` asks for the Grafana Cloud token (1Password item
`Grafana Cloud`, field `credential`). A remote run does not copy your local
environment, so fnox can't supply it; endpoints and user IDs aren't secret and
live in `mise.toml` as vars. Re-running applies config changes, and Alloy
restarts only when a managed file changes.

mise never removes anything on its own. Delete a file by declaring it
`state = "absent"` (as `mise.obsidian.toml` does for retired config files);
packages and services need manual removal.

## Notes

- Alloy's UI listens on localhost only: `ssh -L 12345:localhost:12345 <host>`.
- The Grafana apt signing key expires 2027-08-22. Update the pinned fingerprint
  in `mise.obsidian.toml` when Grafana rotates it.
- `latest` packages only update with `--update` or `mise bootstrap packages upgrade`.

## Apply on web (Uncloud)

```bash
uc deploy
```

Review the plan before confirming; the replacement is `stop-first`, so Alloy is
briefly down. Deploy from inside this directory: Uncloud derives the project
name from it, and the OBI sidecar sends traces to `alloy.internal:4317`. Shared
files are injected into `/etc/alloy/` (copying into a missing directory fails),
and `empty.alloy` replaces the image's default `config.alloy`.
