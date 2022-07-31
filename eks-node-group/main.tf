data "aws_partition" "current" {}

locals {
  policy_arn_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
  iam_role_name     = "MyEKSNodeGroup${title(var.eks_cluster_outputs.cluster_name)}"
}

terraform {
  # Intentionally empty. Will be filled by Terragrunt.
  backend "s3" {}
  required_version = "= 1.1.6"
  required_providers {
    aws = "= 4.10.0"
  }
}

provider "aws" {
  profile             = var.aws_local_profile
  region              = var.region
  allowed_account_ids = split(",", var.aws_allowed_account_ids)
  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/${var.deployment_service_iam_role_name}"
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    sid     = "EKSNodeGroupAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

#https://docs.aws.amazon.com/eks/latest/userguide/security-iam-awsmanpol.html
resource "aws_iam_role" "this" {
  name                  = local.iam_role_name
  description           = "MyEKSNodeGroup${title(var.eks_cluster_outputs.cluster_name)}" #var.iam_role_description
  assume_role_policy    = data.aws_iam_policy_document.assume_role_policy.json
  force_detach_policies = true

  # https://github.com/terraform-aws-modules/terraform-aws-eks/issues/920
  # Resources running on the cluster are still generaring logs when destroying the module resources
  # which results in the log group being re-created even after Terraform destroys it. Removing the
  # ability for the cluster role to create the log group prevents this log group from being re-created
  # outside of Terraform due to services still generating logs during destroy process
  dynamic "inline_policy" {
    for_each = var.create_cloudwatch_log_group ? [1] : []
    content {
      name = local.iam_role_name

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action   = ["logs:CreateLogGroup"]
            Effect   = "Deny"
            Resource = aws_cloudwatch_log_group.this.arn
          },
        ]
      })
    }
  }

  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_core_outputs.vpc_name}-${var.eks_cluster_outputs.cluster_name}-eks-cluster" }
  )
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset([
    "${local.policy_arn_prefix}/AmazonEKSWorkerNodePolicy",
    "${local.policy_arn_prefix}/AmazonEC2ContainerRegistryReadOnly",
    "${local.policy_arn_prefix}/AmazonEKS_CNI_Policy"
  ])
  policy_arn = each.value
  role       = aws_iam_role.this.name
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/eks/${var.eks_cluster_outputs.cluster_name}/nodegroups"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_core_outputs.vpc_name}-${var.eks_cluster_outputs.cluster_name}-nodegroups" }
  )
}

#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group
resource "aws_eks_node_group" "example" {
  cluster_name    = var.eks_cluster_outputs.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.this.arn
  subnet_ids      = [var.vpc_core_outputs.subnet_ids["${var.vpc_core_outputs.vpc_name}-private-primary"], var.vpc_core_outputs.subnet_ids["${var.vpc_core_outputs.vpc_name}-private-secondary"]]

  scaling_config {
    desired_size = var.scaling_config_desired_size
    max_size     = var.scaling_config_max_size
    min_size     = var.scaling_config_min_size
  }

  update_config {
    max_unavailable = var.max_unavailable
    max_unavailable_percentage  = var.max_unavailable_percentage
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.this,
    aws_iam_role.this
  ]
}