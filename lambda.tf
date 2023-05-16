data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_policy" "rootmail_policy" {
  name = "RootMail_Lambda_Policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
        ],
        "Resource" : "arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.email_bucket.bucket}/RootMail/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:CreateOpsItem",
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:PutParameter",
        ],
        "Resource" : "arn:${data.aws_partition.current.partition}:ssm:${var.ses_region}:${local.account_id}:parameter/rootmail/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.rootmail_policy.arn
}


resource "aws_iam_role_policy_attachment" "terraform_base_lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "local_file" "zipfile" {
  filename = local.zip_filename
}

resource "aws_lambda_function" "rootmail_receiver_lambda" {
  provider = aws.ses_region

  filename      = local.zip_filename
  function_name = local.function_name
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.handler"

  source_code_hash = data.local_file.zipfile.content_base64sha256

  runtime = "nodejs16.x"

  environment {
    variables = {
      EmailBucket  = aws_s3_bucket.email_bucket.bucket
      BucketRegion = aws_s3_bucket.email_bucket.region
    }
  }
}

resource "aws_lambda_permission" "allow_ses_access" {
  provider       = aws.ses_region
  statement_id   = "AllowExecutionFromSES"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.rootmail_receiver_lambda.function_name
  principal      = "ses.amazonaws.com"
  source_account = local.account_id
}

resource "aws_cloudwatch_log_group" "example" {
  provider          = aws.ses_region
  name              = "/aws/lambda/${aws_lambda_function.rootmail_receiver_lambda.function_name}"
  retention_in_days = 14
}
