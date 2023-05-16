data "aws_route53_zone" "primary" {
  name = local.domain
}

resource "aws_ses_domain_identity" "domain_identity" {
  domain = local.domain
}

resource "aws_ses_domain_dkim" "example" {
  domain = aws_ses_domain_identity.domain_identity.domain
}

resource "aws_route53_record" "mx_record" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.domain
  type    = "MX"
  ttl     = "60"
  records = ["10 inbound-smtp.eu-west-1.amazonaws.com"]
}

resource "aws_route53_record" "example_amazonses_verification_record" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "_amazonses.${aws_ses_domain_identity.domain_identity.id}"
  type    = "TXT"
  ttl     = "60"
  records = [aws_ses_domain_identity.domain_identity.verification_token]
}

resource "aws_route53_record" "example_amazonses_dkim_record" {
  count   = 3
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${aws_ses_domain_dkim.example.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${aws_ses_domain_dkim.example.dkim_tokens[count.index]}.dkim.amazonses.com"]
}
