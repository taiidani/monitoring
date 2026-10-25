provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}

terraform {
  required_version = ">= 1.11"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.0"
    }
  }

  cloud {
    organization = "rnd"

    workspaces {
      name = "monitoring"
    }
  }
}
