#
# Input Variables
#

variable "zone_id" {
  description = "The Cloudflare zone ID for the domain"
}

variable "domain" {
  description = "The target domain (e.g. example.com)"
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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
  required_version = ">= 0.13"
}

#
# Records
#

resource "cloudflare_dns_record" "mx" {
  zone_id  = var.zone_id
  name     = var.domain
  priority = 1
  ttl      = 1
  type     = "MX"
  content  = "aspmx.l.google.com"
}

resource "cloudflare_dns_record" "mx_alt1" {
  zone_id  = var.zone_id
  name     = var.domain
  priority = 5
  ttl      = 1
  type     = "MX"
  content  = "alt1.aspmx.l.google.com"
}

resource "cloudflare_dns_record" "mx_alt2" {
  zone_id  = var.zone_id
  name     = var.domain
  priority = 5
  ttl      = 1
  type     = "MX"
  content  = "alt2.aspmx.l.google.com"
}

resource "cloudflare_dns_record" "mx_alt3" {
  zone_id  = var.zone_id
  name     = var.domain
  priority = 10
  ttl      = 1
  type     = "MX"
  content  = "alt3.aspmx.l.google.com"
}

resource "cloudflare_dns_record" "mx_alt4" {
  zone_id  = var.zone_id
  name     = var.domain
  priority = 10
  ttl      = 1
  type     = "MX"
  content  = "alt4.aspmx.l.google.com"
}

resource "cloudflare_dns_record" "spf" {
  zone_id = var.zone_id
  name    = var.domain
  ttl     = 1
  type    = "TXT"
  content = var.spf
}

resource "cloudflare_dns_record" "verification" {
  count = var.verification == "" ? 0 : 1

  zone_id = var.zone_id
  name    = var.domain
  ttl     = 1
  type    = "TXT"
  content = "\"google-site-verification=${var.verification}\""
}
