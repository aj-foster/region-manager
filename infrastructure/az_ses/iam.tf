#
# User for Sending
#

resource "aws_iam_user" "this" {
  name = "ses-smtp-${replace(var.email, "/[@.]/", "-")}"

  tags = {
    group   = var.group
    service = "ses"
  }
}

resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}

#
# Policy: Allow sending via given address; restrict to sender_ips if provided
#

data "aws_iam_policy_document" "this" {
  statement {
    actions   = ["ses:SendRawEmail"]
    resources = [aws_ses_email_identity.email.arn]

    dynamic "condition" {
      for_each = var.sender_ips

      content {
        test     = "IpAddress"
        variable = "aws:SourceIp"
        values   = var.sender_ips
      }
    }
  }
}

#
# Attach Policy
#

resource "aws_iam_policy" "this" {
  name   = "${aws_iam_user.this.name}--sender"
  path   = "/"
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_iam_user_policy_attachment" "this" {
  user       = aws_iam_user.this.name
  policy_arn = aws_iam_policy.this.arn
}
