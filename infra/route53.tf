# Four records: A and AAAA, for the apex and for www. setproduct gives us both
# dimensions in one resource block instead of four near-identical ones.
resource "aws_route53_record" "alias" {
  for_each = {
    for pair in setproduct(local.aliases, ["A", "AAAA"]) :
    "${pair[0]}-${pair[1]}" => { name = pair[0], type = pair[1] }
  }

  zone_id = data.aws_route53_zone.site.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name = aws_cloudfront_distribution.site.domain_name

    # CloudFront's hosted zone ID is a fixed constant (Z2FDTNDATAQYW2), but
    # reading it off the distribution is safer than hardcoding it.
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
