#
# Input Variables
#

variable "domain" {
  description = "The APEX domain (e.g. example.com)"
}

variable "sub_domain" {
  description = "The sub-domain for the MX records, if applicable"
  default     = "@"
}

variable "verification" {
  description = "Code used by Google to verify domain ownership"
  default     = ""
}

variable "spf" {
  description = "Optional override for the SPF record value"
  default     = "\"v=spf1 a include:_spf.google.com ~all\""
}

#
# Providers
#

terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
  required_version = ">= 0.13"
}

#
# Records
#

resource "digitalocean_record" "mx" {
  domain   = var.domain
  name     = var.sub_domain
  priority = 1
  ttl      = 3600
  type     = "MX"
  value    = "aspmx.l.google.com."
}

resource "digitalocean_record" "mx_alt1" {
  domain   = var.domain
  name     = var.sub_domain
  priority = 5
  ttl      = 3600
  type     = "MX"
  value    = "alt1.aspmx.l.google.com."
}

resource "digitalocean_record" "mx_alt2" {
  domain   = var.domain
  name     = var.sub_domain
  priority = 5
  ttl      = 3600
  type     = "MX"
  value    = "alt2.aspmx.l.google.com."
}

resource "digitalocean_record" "mx_alt3" {
  domain   = var.domain
  name     = var.sub_domain
  priority = 10
  ttl      = 3600
  type     = "MX"
  value    = "alt3.aspmx.l.google.com."
}

resource "digitalocean_record" "mx_alt4" {
  domain   = var.domain
  name     = var.sub_domain
  priority = 10
  ttl      = 3600
  type     = "MX"
  value    = "alt4.aspmx.l.google.com."
}

resource "digitalocean_record" "spf" {
  domain = var.domain
  name   = var.sub_domain
  ttl    = 3600
  type   = "TXT"
  value  = var.spf
}

resource "digitalocean_record" "verification" {
  count = var.verification == "" ? 0 : 1

  domain = var.domain
  name   = var.sub_domain
  ttl    = 3600
  type   = "TXT"
  value  = "google-site-verification=${var.verification}"
}
