resource "aws_ses_receipt_rule_set" "main" {
  provider      = aws.ses_region
  rule_set_name = "RootMail"
}

resource "aws_ses_receipt_rule" "store" {
  provider      = aws.ses_region
  name          = "Receive"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  recipients    = ["root@${local.domain}"]
  enabled       = true
  scan_enabled  = true
  tls_policy    = "Require"

  s3_action {
    bucket_name       = aws_s3_bucket.email_bucket.bucket
    object_key_prefix = "RootMail"
    position          = 1

  }

  lambda_action {
    function_arn = aws_lambda_function.rootmail_receiver_lambda.arn
    position     = 2
  }
}

resource "aws_ses_active_receipt_rule_set" "main" {
  provider      = aws.ses_region
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
}
