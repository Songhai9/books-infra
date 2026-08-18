data "aws_partition" "current" {}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "AllowEC2Assumption"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "kubernetes_control_plane" {
  name_prefix        = "${local.name_prefix}-k8s-control-plane-"
  description        = "Instance role for the Book Notes kubeadm control plane"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "kubernetes_control_plane_ssm" {
  role       = aws_iam_role.kubernetes_control_plane.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "kubernetes_control_plane" {
  name_prefix = "${local.name_prefix}-k8s-control-plane-"
  role        = aws_iam_role.kubernetes_control_plane.name
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]
}

data "aws_iam_policy_document" "github_kubernetes_cd_assume_role" {
  statement {
    sid     = "AllowGitHubMainBranch"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

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
      values   = [var.github_kubernetes_cd_subject]
    }
  }

  statement {
    sid     = "AllowApplicationReleaseTags"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

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
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_application_release_subject]
    }
  }
}

resource "aws_iam_role" "github_kubernetes_cd" {
  name                 = "${local.name_prefix}-github-kubernetes-cd"
  description          = "Temporary GitHub Actions access for Book Notes Kubernetes deployments"
  assume_role_policy   = data.aws_iam_policy_document.github_kubernetes_cd_assume_role.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_kubernetes_cd" {
  statement {
    sid     = "RunDeploymentOnControlPlane"
    effect  = "Allow"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::document/AWS-RunShellScript",
      aws_instance.kubernetes_control_plane.arn,
    ]
  }

  statement {
    sid     = "ReadDeploymentResult"
    effect  = "Allow"
    actions = ["ssm:GetCommandInvocation"]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "github_kubernetes_cd" {
  name   = "kubernetes-deployment"
  role   = aws_iam_role.github_kubernetes_cd.id
  policy = data.aws_iam_policy_document.github_kubernetes_cd.json
}
