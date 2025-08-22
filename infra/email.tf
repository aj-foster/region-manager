# Amazon Web Services Simple Email Service (AWS SES)
#
# This module defines all of the infrastructure for sending email using SES as well as several
# domain records for verifying ownership to AWS.

module "az_ses" {
  source = "./az_ses"

  domain             = var.domain
  email              = "no-reply@${var.domain}"
  group              = "ftcregion"
  create_do_records  = true
  sender_ips         = []
  cloudflare_zone_id = cloudflare_zone.this.id
}

#
# Delivery Notifications
#

resource "aws_sns_topic" "delivery_notifications" {
  name              = "ftcregion-ses-delivery-notifications"
  display_name      = "FTC Region Manager SES Delivery Notifications"
  kms_master_key_id = "alias/aws/sns"
  signature_version = 2

  tags = {
    service = "ses"
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "notification-policy"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ses.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = "arn:aws:sns:us-east-1:${local.aws_account_id}:ftcregion-ses-delivery-notifications"
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" : "${local.aws_account_id}"
            "AWS:SourceArn" : "arn:aws:ses:us-east-1:${local.aws_account_id}:identity/ftcregion.com"
          }
        }
      }
    ]
  })

  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        numRetries      = 3
        minDelayTarget  = 20
        maxDelayTarget  = 20
        backoffFunction = "linear"
      }
      disableSubscriptionOverrides = false
      defaultRequestPolicy = {
        headerContentType = "application/json"
      }
    }
  })
}
