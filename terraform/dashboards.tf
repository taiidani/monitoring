resource "grafana_folder" "home_lab" {
  title = "Home Lab"
}

# Every JSON file in ../dashboards is applied into the Home Lab folder. Edits
# made in the UI are overwritten on the next apply, so change the JSON instead.
resource "grafana_dashboard" "home_lab" {
  for_each = fileset("${path.module}/../dashboards", "*.json")

  folder      = grafana_folder.home_lab.uid
  config_json = file("${path.module}/../dashboards/${each.value}")
  overwrite   = true
}
