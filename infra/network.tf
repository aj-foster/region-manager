# VPC (private network) and Firewall
#
# The ip_addr rule for the firewall adds your current IP address as an allowed client for the
# managed database. This is optional, but convenient for debugging.

resource "digitalocean_vpc" "this" {
  name   = "vp-ftcregion"
  region = "nyc3"
}

resource "digitalocean_database_firewall" "app-db" {
  cluster_id = digitalocean_database_cluster.this.id

  rule {
    type  = "app"
    value = digitalocean_app.this.id
  }

  rule {
    type  = "ip_addr"
    value = trimspace(data.http.local_ip_address.response_body)
  }
}
