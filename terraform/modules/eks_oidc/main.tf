data "tls_certificate" "eks_thumbprint" {
  url = var.eks_oidc_url
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  url             = var.eks_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_thumbprint.certificates[0].sha1_fingerprint]
}
