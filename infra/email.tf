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

#
# Delivery Notifications
#

resource "aws_sns_topic" "delivery_notifications" {
  name              = "ftcregion-ses-delivery-notifications"
  display_name      = "FTC Region Manager SES Delivery Notifications"
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

resource "aws_sns_topic_subscription" "delivery_notifications" {
  topic_arn = aws_sns_topic.delivery_notifications.arn
  protocol  = "https"
  endpoint  = "https://${var.rm_sns_username}:${var.rm_sns_password}@${var.domain}/hook/ses-delivery"
}

resource "aws_ses_identity_notification_topic" "bounce" {
  topic_arn                = aws_sns_topic.delivery_notifications.arn
  notification_type        = "Bounce"
  identity                 = module.az_ses.domain_identity
  include_original_headers = true

  depends_on = [aws_sns_topic_subscription.delivery_notifications]
}

resource "aws_ses_identity_notification_topic" "complaint" {
  topic_arn                = aws_sns_topic.delivery_notifications.arn
  notification_type        = "Complaint"
  identity                 = module.az_ses.domain_identity
  include_original_headers = true

  depends_on = [aws_sns_topic_subscription.delivery_notifications]
}
