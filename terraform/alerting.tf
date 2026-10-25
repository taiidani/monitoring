resource "grafana_folder" "alerts" {
  title = "Alerts"
}

resource "grafana_contact_point" "discord" {
  name = "Discord"

  discord {
    url                     = var.discord_webhook_url
    disable_resolve_message = false
  }
}

# The notification policy tree is a single resource; this routes every alert to
# the Discord contact point.
resource "grafana_notification_policy" "default" {
  contact_point = grafana_contact_point.discord.name
  group_by      = ["grafana_folder", "alertname"]

  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"
}

locals {
  host_rules = {
    host_down = {
      title       = "Host Down"
      expr        = "up{job=\"node\"}"
      comparator  = "lt"
      threshold   = 1
      for         = "5m"
      severity    = "critical"
      summary     = "Host {{ $labels.instance }} is down"
      description = "node metrics from {{ $labels.instance }} have not been reported for 5 minutes."
    }
    disk_high = {
      title       = "Host Root Disk Usage High"
      expr        = "100 - (node_filesystem_avail_bytes{mountpoint=\"/\",fstype!=\"tmpfs\"} / node_filesystem_size_bytes{mountpoint=\"/\",fstype!=\"tmpfs\"} * 100)"
      comparator  = "gt"
      threshold   = 85
      for         = "10m"
      severity    = "warning"
      summary     = "Root filesystem on {{ $labels.instance }} is over 85% full"
      description = "Root (/) usage on {{ $labels.instance }} has exceeded 85% for 10 minutes."
    }
    memory_high = {
      title       = "Host Memory Usage High"
      expr        = "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))"
      comparator  = "gt"
      threshold   = 90
      for         = "10m"
      severity    = "warning"
      summary     = "Memory on {{ $labels.instance }} is over 90%"
      description = "Memory usage on {{ $labels.instance }} has exceeded 90% for 10 minutes."
    }
  }
}

resource "grafana_rule_group" "host_health" {
  name             = "Host Health"
  folder_uid       = grafana_folder.alerts.uid
  interval_seconds = 60

  dynamic "rule" {
    for_each = local.host_rules

    content {
      name           = rule.value.title
      condition      = "C"
      for            = rule.value.for
      no_data_state  = "NoData"
      exec_err_state = "Error"

      labels = {
        severity = rule.value.severity
      }

      annotations = {
        summary     = rule.value.summary
        description = rule.value.description
      }

      data {
        ref_id         = "A"
        datasource_uid = var.prometheus_datasource_uid

        relative_time_range {
          from = 600
          to   = 0
        }

        model = jsonencode({
          refId         = "A"
          expr          = rule.value.expr
          instant       = true
          intervalMs    = 1000
          maxDataPoints = 43200
          datasource = {
            type = "prometheus"
            uid  = var.prometheus_datasource_uid
          }
        })
      }

      data {
        ref_id         = "B"
        datasource_uid = "__expr__"

        relative_time_range {
          from = 600
          to   = 0
        }

        model = jsonencode({
          refId      = "B"
          type       = "reduce"
          reducer    = "last"
          expression = "A"
          datasource = {
            type = "__expr__"
            uid  = "__expr__"
          }
        })
      }

      data {
        ref_id         = "C"
        datasource_uid = "__expr__"

        relative_time_range {
          from = 600
          to   = 0
        }

        model = jsonencode({
          refId      = "C"
          type       = "threshold"
          expression = "B"
          conditions = [{
            evaluator = {
              type   = rule.value.comparator
              params = [rule.value.threshold]
            }
          }]
          datasource = {
            type = "__expr__"
            uid  = "__expr__"
          }
        })
      }
    }
  }
}
