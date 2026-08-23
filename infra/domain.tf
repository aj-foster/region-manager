# DigitalOcean DNS records
#
# The _domain below tells DO that it will be authoritative for the domain, and the do_mx_google
# module defines a number of records for receiving mail using Google Workspace.

resource "digitalocean_domain" "this" {
  name = var.domain
}

module "do_mx_google" {
  source = "./do_mx_google"
  domain = digitalocean_domain.this.name

  # Provided by Google when adding a domain to Google Workspace
  verification = "qRA_wnz18-92Ek_-eu32h2hPGTH3PPZvbo9uzUdjKGA"
  dkim = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoD+Z8T0YX7ljkqAJ+ik9dlTAXsPOahqQtHiaQc2SHTl/ou/1eOSzh96XjMESulbhymRuEr3VGv3Za9STiE7IjI508td5kTBCRINwDeSSPoQ27ol+FG90TEcGB/mjhVIIi83c4lx8JLHLrgtuhQiWBXBqM2UY1UiKFTiJJ9m2J16fjg40qfXuujGpyMcADuM4w7gwKrN0JsNbvFkCWt4B1EQZe2WZcfR1uL4lVllwq6NNPfqroXbOaThAm1kzPYHLKJ2+L/uBFj2pJ981zlgCDzNBTuNXjzAzAwUXsRv59zUUaSe90AeO0WIh4x6dqbnl3dntXE80J5Pe5zn9KE3BZwIDAQAB"
}
