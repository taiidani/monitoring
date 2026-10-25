variable "grafana_url" {
  description = "URL of the Grafana Cloud stack, e.g. https://<stack>.grafana.net/"
  type        = string
}

variable "grafana_auth" {
  description = "Grafana service account token (Admin role) used by the provider."
  type        = string
  sensitive   = true
}

variable "discord_webhook_url" {
  description = "Discord webhook for the alert contact point."
  type        = string
  sensitive   = true
}

variable "oidc_client_secret" {
  description = "Authelia OIDC client secret for the grafana client."
  type        = string
  sensitive   = true
}

variable "prometheus_datasource_uid" {
  description = "UID of the Grafana Cloud Prometheus datasource."
  type        = string
  default     = "grafanacloud-prom"
}
