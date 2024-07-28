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
}
