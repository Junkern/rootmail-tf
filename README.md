# RootMail TF

This Terraform module sets up the RootMail feature described by https://github.com/superwerker/superwerker/blob/main/docs/adrs/rootmail.md

It currently provides the same functionality as the RootMail feature deployed by superwerker with a few small differences:

* It is written in Terraform. The RootMail feature of superwerker is written in CloudFormation
* It is standalone. The RootMail feature of superwerker is part of superwerker and cannot be deployed without copying around yml files

## Installation

Simply use this repository as an module an provide the following parameters:

* `domain`: The domain used for the email addresses
* `ses_region`: Region used for all resources handling the SES setup. Defaults to `eu-west-1`. Please only specify regions in which SES service is available.
* `region`: Region used for all other resources. Defaults to `eu-central-1`

The module currently assumes that the hosted zone of `domain` already exist.

## Why?

If you are wondering why you should use the RootMail feature, please see https://github.com/superwerker/superwerker/blob/main/docs/adrs/rootmail.md

## Technical details

### S3 Bucket action in SES receipt rule

In the SES receipt rule you can directly specify an Lambda ARN, but then the message body will not be contained in the event (https://docs.aws.amazon.com/ses/latest/dg/receiving-email-action-lambda-event.html#receiving-email-action-lambda-event-lambdaaction)
You either have to use an SNS queue or an S3 bucket as an intermediate step.
SNS queue has the drawback that the maximum size is 150KB: https://docs.aws.amazon.com/ses/latest/dg/receiving-email-action-sns.html
So, in order to be not limited by this, we use an S3 bucket action

## Developing

When you change application logic inside the lambda, please execute `bash ./scripts/build.sh` and commit the changed `lambda_function_payload.zip`.

## Credits

All credit belongs to https://github.com/superwerker/superwerker, that's where the RootMail feature was initially introduced.