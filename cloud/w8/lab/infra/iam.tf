data "aws_iam_policy_document" "kubeconfig_writer" {
  statement {
    sid = "WriteKubeconfigParameter"

    actions = [
      "ssm:PutParameter",
    ]

    resources = [
      local.kubeconfig_ssm_parameter_arn,
    ]
  }

  statement {
    sid = "EncryptSsmSecureString"

    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_policy" "kubeconfig_writer" {
  name_prefix = "${local.name_prefix}-kubeconfig-"
  description = "Allows the kind host to publish kubeconfig to one SSM parameter"
  policy      = data.aws_iam_policy_document.kubeconfig_writer.json

  tags = local.tags
}
