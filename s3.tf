
resource "aws_s3_bucket" "email_bucket" {
  bucket = local.bucket_name

}

resource "aws_s3_bucket_policy" "allow_access_from_another_region" {
  bucket = aws_s3_bucket.email_bucket.id
  policy = data.aws_iam_policy_document.allow_access_from_another_account.json
}

data "aws_iam_policy_document" "allow_access_from_another_account" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:Referer"
      values   = [local.account_id]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.email_bucket.bucket}/RootMail/*",
    ]
  }
}
