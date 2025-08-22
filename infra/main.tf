variable "domain" {
  description = "Top-level domain where the application is hosted"
  default     = "ftcregion.com"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 2.1"
    }
  }
}

# Hostname, such as "assets.ftcregion.com"
variable "rm_asset_host" {}

# Full contents of the `.crt` file supplied by DigitalOcean when creating a managed database
variable "rm_database_cacert" { sensitive = true }

# "ecto://username:password@host:port/database_name"
variable "rm_database_url" { sensitive = true }

# UUID supplied by the FTC Events API developers
variable "rm_ftc_events_api_key" { sensitive = true }

# Username supplied by the FTC Events API developers
variable "rm_ftc_events_api_user" { sensitive = true }

# Use `mix phx.gen.secret` in the root of this project to generate a secret
variable "rm_secret_key_base" { sensitive = true }

# Username for HTTP Basic Auth used by SNS when delivering messages
variable "rm_sns_username" { sensitive = true }

# Use `mix phx.gen.secret` in the root of this project to generate a password
variable "rm_sns_password" { sensitive = true }

# DigitalOcean Spaces or other S3-compatible access ID and secret key
variable "rm_spaces_access_id" { sensitive = true }
variable "rm_spaces_access_key" { sensitive = true }

# S3-compatible bucket hostname, such as "mybucket.nyc3.digitaloceanspaces.com"
variable "rm_spaces_host" {}

# Bucket name, such as "mybucket"
variable "rm_storage_bucket" {}

#
# Amazon Web Services
#

# IAM access ID and secret key for setting up AWS SES infrastructure
variable "az_access_key" { sensitive = true }
variable "az_secret_key" { sensitive = true }

provider "aws" {
  region     = "us-east-1"
  access_key = var.az_access_key
  secret_key = var.az_secret_key

  default_tags {
    tags = {
      group = "ftcregion"
    }
  }
}

data "aws_caller_identity" "this" {}
locals {
  aws_account_id = data.aws_caller_identity.this.account_id
}

#
# Digital Ocean
#

# API token for DigitalOcean
variable "do_token" {}

provider "digitalocean" {
  spaces_access_id  = var.rm_spaces_access_id
  spaces_secret_key = var.rm_spaces_access_key
  token             = var.do_token
}

#
# Other
#

provider "http" {}

data "http" "local_ip_address" {
  url = "http://ipv4.icanhazip.com"
}

#
# Resources
#

resource "digitalocean_project" "this" {
  name        = "FTC Region Manager"
  description = "ftcregion.com"
  purpose     = "Web Application"
  environment = "Production"

  resources = [
    digitalocean_app.this.urn,
    digitalocean_database_cluster.this.urn,
    digitalocean_domain.this.urn,
    digitalocean_spaces_bucket.assets.urn
  ]
}

resource "digitalocean_tag" "this" {
  name = "ftcregion"
}
