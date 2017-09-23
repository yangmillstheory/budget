# note that SMS topic subscriptions are unsupported in Terraform, so
# those are not included in this module.
#
#   https://www.terraform.io/docs/providers/aws/r/sns_topic_subscription.html
output "ok_arn" {
  value = "${aws_sns_topic.budget_update.arn}"
}

output "error_arn" {
  value = "${aws_sns_topic.budget_update_error.arn}"
}

output "reset_arn" {
  value = "${aws_sns_topic.budget_reset.arn}"
}

resource "aws_sns_topic" "budget_update" {
  name         = "budget-update-ok"
  display_name = "Budget Update"
}

resource "aws_sns_topic" "budget_update_error" {
  name         = "budget-update-error"
  display_name = "Budget Update Error"
}

resource "aws_sns_topic" "budget_reset" {
  name         = "budget-reset"
  display_name = "Budget Reset"
}

data "aws_iam_policy_document" "lambda_ok" {
  statement {
    sid = "1"

    actions = [
      "sns:Publish",
    ]

    resources = [
      "${aws_sns_topic.budget_update.arn}",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_reset" {
  statement {
    sid = "1"

    actions = [
      "sns:Publish",
    ]

    resources = [
      "${aws_sns_topic.budget_reset.arn}",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "lambda_publish_ok" {
  arn    = "${aws_sns_topic.budget_update.arn}"
  policy = "${data.aws_iam_policy_document.lambda_ok.json}"
}

resource "aws_sns_topic_policy" "lambda_publish_reset" {
  arn    = "${aws_sns_topic.budget_reset.arn}"
  policy = "${data.aws_iam_policy_document.lambda_reset.json}"
}

resource "aws_s3_bucket" "sns_logs" {
  bucket = "budget-sns-logs"
}

data "aws_iam_policy_document" "sns_to_s3" {
  statement {
    sid = "1"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.sns_logs.arn}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket_policy" "sns_logs" {
  bucket = "${aws_s3_bucket.sns_logs.id}"
  policy = "${data.aws_iam_policy_document.sns_to_s3.json}"
}

data "aws_iam_policy_document" "sns_assume_role" {
  statement {
    sid = "1"

    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_logger" {
  name = "CloudWatchLogger"
  assume_role_policy = "${data.aws_iam_policy_document.sns_assume_role.json}"
}

data "aws_iam_policy_document" "sns_to_cloudwatch" {
  statement {
    sid = "1"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutMetricFilter",
      "logs:PutRetentionPolicy"
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "sns_to_cloudwatch" {
  name = "SNSToCloudWatch"
  policy = "${data.aws_iam_policy_document.sns_to_cloudwatch.json}"
}

# this is done via the AWS console
#
# resource "aws_iam_policy_attachment" "cloudwatch_logger" {
#   name = "${aws_iam_role.cloudwatch_logger.name}"
#   policy_arn = "${aws_iam_policy.sns_to_cloudwatch.arn}"
# }
