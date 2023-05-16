variable "ses_region" {
  type        = string
  default     = "eu-west-1"
  description = "Region used for all resources handling the SES setup"
}

variable "region" {
  type        = string
  default     = "eu-central-1"
  description = "Region used for all other resources"
}

variable "domain" {
  type        = string
  description = "The domain used for the email addresses"
}
