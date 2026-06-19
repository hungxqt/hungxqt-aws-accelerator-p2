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
  description = "Allows the minikube host to publish kubeconfig to one SSM parameter"
  policy      = data.aws_iam_policy_document.kubeconfig_writer.json

  tags = local.tags
}

data "aws_iam_policy_document" "secrets_reader" {
  statement {
    sid = "ReadSecretsManager"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:minikube-sandbox/github-pat-*",
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:minikube-sandbox/smtp-password-*",
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:minikube-sandbox/redis-password-*",
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:minikube-sandbox/cosign-key-*",
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:minikube-sandbox/cosign-password-*",
    ]
  }
}

resource "aws_iam_policy" "secrets_reader" {
  name_prefix = "${local.name_prefix}-secrets-"
  description = "Allows the minikube host to read GitHub PAT and SMTP password from Secrets Manager"
  policy      = data.aws_iam_policy_document.secrets_reader.json

  tags = local.tags
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]

  tags = local.tags
}

data "aws_iam_policy_document" "github_actions_cosign_assume_role" {
  statement {
    sid = "AllowMainBranchGitHubActions"

    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn,
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_actions_repository}:ref:refs/heads/${var.github_actions_branch}"]
    }
  }
}

resource "aws_iam_role" "github_actions_cosign_secrets" {
  name               = "${local.name_prefix}-gha-cosign"
  description        = "Allows GitHub Actions to read only Cosign signing secrets"
  assume_role_policy = data.aws_iam_policy_document.github_actions_cosign_assume_role.json

  tags = local.tags
}

data "aws_iam_policy_document" "github_actions_cosign_secrets_reader" {
  statement {
    sid = "ReadOnlyCosignSigningSecrets"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:minikube-sandbox/cosign-key-*",
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:minikube-sandbox/cosign-password-*",
    ]
  }
}

resource "aws_iam_policy" "github_actions_cosign_secrets_reader" {
  name        = "${local.name_prefix}-gha-cosign-secrets"
  description = "Allows GitHub Actions to read the Cosign private key and password"
  policy      = data.aws_iam_policy_document.github_actions_cosign_secrets_reader.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "github_actions_cosign_secrets_reader" {
  role       = aws_iam_role.github_actions_cosign_secrets.name
  policy_arn = aws_iam_policy.github_actions_cosign_secrets_reader.arn
}


