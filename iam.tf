# ---------- Module 4: IAM - boundary, MFA-enforced role, CI role ----------
resource "aws_iam_policy" "boundary" {
  name        = "${local.name}-permission-boundary"
  description = "Caps what any developer role can ever do"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "AllowProjectServices", Effect = "Allow", Action = ["ec2:*", "s3:*", "dynamodb:*", "lambda:*", "logs:*", "cloudwatch:*", "kinesis:*", "athena:*", "glue:*", "ecr:*", "eks:Describe*", "eks:List*", "rds:Describe*", "apigateway:GET"], Resource = "*" },
      { Sid = "DenyIamAndBillingChanges", Effect = "Deny", Action = ["iam:*", "organizations:*", "account:*", "aws-portal:*"], Resource = "*" }
    ]
  })
}

data "aws_iam_policy_document" "dev_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.me.account_id}:root"]
    }
    condition { # MFA is mandatory to assume the role
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role" "developer" {
  name                 = "${local.name}-developer"
  assume_role_policy   = data.aws_iam_policy_document.dev_trust.json
  permissions_boundary = aws_iam_policy.boundary.arn
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "developer_power" {
  role       = aws_iam_role.developer.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess" # effective permissions = PowerUser ∩ boundary
}

resource "aws_iam_role" "readonly" {
  name               = "${local.name}-auditor"
  assume_role_policy = data.aws_iam_policy_document.dev_trust.json
}

resource "aws_iam_role_policy_attachment" "readonly" {
  role       = aws_iam_role.readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Account password policy
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  password_reuse_prevention      = 5
  max_password_age               = 90
  allow_users_to_change_password = true
}

# GitHub Actions -> AWS with short-lived OIDC credentials (no stored access keys)
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.github_repo != "" ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_ci" {
  count = var.github_repo != "" ? 1 : 0
  name  = "${local.name}-github-ci"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github[0].arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_ci" {
  count = var.github_repo != "" ? 1 : 0
  role  = aws_iam_role.github_ci[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"], Resource = [for r in aws_ecr_repository.svc : r.arn] },
      { Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = "*" },
      { Effect = "Allow", Action = ["lambda:UpdateFunctionCode"], Resource = [aws_lambda_function.api.arn, aws_lambda_function.receipt_processor.arn] }
    ]
  })
}
