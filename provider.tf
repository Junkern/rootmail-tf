terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "ses_region"
  region = var.ses_region
}

locals {
  domain        = var.domain
  account_id    = data.aws_caller_identity.current.account_id
  function_name = "lambda_function_name"
  zip_filename  = "lambda_function_payload.zip"
  bucket_name   = "${local.domain}-rootmail-bucket"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
