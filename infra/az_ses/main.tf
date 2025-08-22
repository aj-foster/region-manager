#
# Input Variables
#

variable "domain" {
  description = "Sending domain (e.g. example.com)"
}

variable "email" {
  description = "Sending address (e.g. no-reply@example.com)"
}

variable "group" {
  description = "Project, as used in AWS tags"
  default     = "global"
}

variable "create_cf_records" {
  description = "Whether to create a Cloudflare DNS record for domain verification"
  default     = false
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain"
  default     = ""
}

variable "create_do_records" {
  description = "Whether to create a DigitalOcean domain record for domain verification"
  default     = false
}

variable "sender_ips" {
  description = "IP addresses or CIDR blocks from which mail can be sent. By default, any IP is allowed"
  default     = []
}

#
# Email Address
#

resource "aws_ses_email_identity" "email" {
  email = var.email
}

#
# Output Variables
#

output "smtp_password" {
  value = aws_iam_access_key.this.ses_smtp_password_v4
}

output "smtp_username" {
  value = aws_iam_access_key.this.id
}

#
# Providers
#

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
  required_version = ">= 0.13"
}
