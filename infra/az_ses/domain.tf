#
# Domain Verification
#

resource "aws_ses_domain_identity" "domain" {
  domain = var.domain
}

resource "cloudflare_dns_record" "ses_verification" {
  zone_id = var.cloudflare_zone_id
  name    = "_amazonses.${var.domain}"
  ttl     = 1
  type    = "TXT"
  content = "\"${aws_ses_domain_identity.domain.verification_token}\""
}

resource "digitalocean_record" "ses_verification" {
  count = var.create_do_records ? 1 : 0

  domain = var.domain
  name   = "_amazonses"
  ttl    = 3600
  type   = "TXT"
  value  = aws_ses_domain_identity.domain.verification_token
}

resource "aws_ses_domain_identity_verification" "ses_verification" {
  domain     = aws_ses_domain_identity.domain.id
  depends_on = [digitalocean_record.ses_verification]
}

#
# DKIM Records
#

resource "aws_ses_domain_dkim" "this" {
  domain = var.domain
}

resource "cloudflare_dns_record" "dkim" {
  count = var.create_cf_records ? 3 : 0

  zone_id = var.cloudflare_zone_id
  name    = "${element(aws_ses_domain_dkim.this.dkim_tokens, count.index)}._domainkey.${var.domain}"
  ttl     = 1
  type    = "CNAME"
  content = "${element(aws_ses_domain_dkim.this.dkim_tokens, count.index)}.dkim.amazonses.com"
}

resource "digitalocean_record" "dkim" {
  count = var.create_do_records ? 3 : 0

  domain = var.domain
  name   = "${element(aws_ses_domain_dkim.this.dkim_tokens, count.index)}._domainkey"
  ttl    = 43200
  type   = "CNAME"
  value  = "${element(aws_ses_domain_dkim.this.dkim_tokens, count.index)}.dkim.amazonses.com."
}

#
# DMARC
#

resource "digitalocean_record" "dmarc" {
  domain = var.domain
  name   = "_dmarc"
  ttl    = 3600
  type   = "TXT"
  value  = "v=DMARC1; p=none; ruf=mailto:${var.email}; fo=1"
}
