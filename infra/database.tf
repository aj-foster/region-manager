# DigitalOcean Managed Database

resource "digitalocean_database_cluster" "this" {
  name                 = "db-ftcregion"
  engine               = "pg"
  version              = "15"
  size                 = "db-s-1vcpu-1gb"
  region               = "nyc3"
  node_count           = 1
  private_network_uuid = digitalocean_vpc.this.id

  tags = [digitalocean_tag.this.name]
}

resource "digitalocean_database_db" "this" {
  cluster_id = digitalocean_database_cluster.this.id
  name       = "ftcregion"
}

resource "digitalocean_database_user" "this" {
  cluster_id = digitalocean_database_cluster.this.id
  name       = "ftcregion"
}

# Note: after creation, must give user permissions on database.
# ALTER DATABASE ftcregion OWNER TO ftcregion;
