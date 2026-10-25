# Monitoring

This is a tracking repository for my monitoring configuration and scripts.
It configures Grafana and my homelab collector configurations.

Grafana configuration as code. Telemetry is collected by Alloy (see [./alloy](./alloy)) and shipped to Grafana Cloud.

| Path          | Managed by                             | Contents                                                              |
| ------------- | -------------------------------------- | --------------------------------------------------------------------- |
| `alloy/`      | Uncloud                                | Deployed into homelab environment                                     |
| `dashboards/` | Terraform (`terraform/dashboards.tf`)  | Dashboard JSON, applied to the _Home Lab_ folder                      |
| `terraform/`  | Terraform Cloud workspace `monitoring` | Dashboards, alert rules, Discord contact point, notification policy, Authelia SSO |

Dashboards are applied by Terraform, so edit the JSON in `dashboards/` rather than the Grafana UI. UI edits are overwritten on the next apply.
