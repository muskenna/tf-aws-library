#iam_role_additional_policies = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]

data "aws_partition" "current" {}

locals {
  policy_arn_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
  iam_role_name     = "MyEKSCluster${title(var.cluster_name)}"
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

#https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  role_arn                  = aws_iam_role.this.arn
  version                   = var.cluster_version
  enabled_cluster_log_types = var.cluster_enabled_log_types

  vpc_config {
    security_group_ids      = [var.security_groups_outputs.security_group_ids[var.eks_secgrp_name]]
    subnet_ids              = [var.vpc_core_outputs.subnet_ids["${var.vpc_core_outputs.vpc_name}-private-primary"], var.vpc_core_outputs.subnet_ids["${var.vpc_core_outputs.vpc_name}-private-secondary"]]
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.cluster_service_ipv4_cidr
  }

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_cloudwatch_log_group.this
  ]

  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_core_outputs.vpc_name}-${var.cluster_name}" }
  )
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_core_outputs.vpc_name}-${var.cluster_name}-cwlogs" }
  )
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    sid     = "EKSClusterAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name                  = local.iam_role_name
  description           = "MyEKSCluster${title(var.cluster_name)}" #var.iam_role_description
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
    { Name = "${var.vpc_core_outputs.vpc_name}-${var.cluster_name}-eks-cluster" }
  )
}

#https://docs.aws.amazon.com/eks/latest/userguide/security-iam-awsmanpol.html
resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset([
    "${local.policy_arn_prefix}/AmazonEKSClusterPolicy",
    "${local.policy_arn_prefix}/AmazonEKSVPCResourceController"
  ])
  policy_arn = each.value
  role       = aws_iam_role.this.name
}
