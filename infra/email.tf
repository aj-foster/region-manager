# Amazon Web Services Simple Email Service (AWS SES)
#
# This module defines all of the infrastructure for sending email using SES as well as several
# domain records for verifying ownership to AWS.

module "az_ses" {
  source = "./az_ses"

  domain            = var.domain
  email             = "no-reply@${var.domain}"
  group             = "ftcregion"
  create_do_records = true
  sender_ips        = []
}
