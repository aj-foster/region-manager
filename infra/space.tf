# DigitalOcean Spaces Object Storage
#
# This defines a storage bucket and CDN for accessing public objects using a nice domain name.

resource "digitalocean_spaces_bucket" "assets" {
  name   = "ftcregion"
  region = "nyc3"
}

resource "digitalocean_record" "assets" {
  domain = digitalocean_domain.this.name
  name   = "assets"
  ttl    = 3600
  type   = "CNAME"
  value  = "ftcregion.nyc3.cdn.digitaloceanspaces.com."
}

resource "digitalocean_certificate" "assets" {
  name    = "ct-com-ftcregion-assets"
  type    = "lets_encrypt"
  domains = ["assets.ftcregion.com", "ftcregion.com"]
}

resource "digitalocean_cdn" "assets" {
  origin           = digitalocean_spaces_bucket.assets.bucket_domain_name
  custom_domain    = "assets.ftcregion.com"
  certificate_name = digitalocean_certificate.assets.name
  ttl              = 604800
}
