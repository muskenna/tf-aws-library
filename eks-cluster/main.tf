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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }

    # kustomization = {
    #   source  = "kbst/kustomization"
    #   version = "0.8.0"
    #   # Version 0.9.0 is broken
      
    # }
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

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.cluster_id]
  }
}

#https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  #https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  version                   = var.kube_version
  enabled_cluster_log_types = var.cluster_enabled_log_types

  vpc_config {
    # Specify one or more security groups for the cross-account elastic network interfaces that Amazon EKS creates to use to allow communication between your worker nodes and the Kubernetes control plane
    security_group_ids = [var.security_groups_outputs.security_group_ids[var.cluster_security_group_name]]
    # Specify subnets for your Amazon EKS worker nodes. Amazon EKS creates cross-account elastic network interfaces in these subnets to allow communication between your worker nodes and the Kubernetes control plane.    
    subnet_ids              = [var.vpc_core_outputs.subnet_ids["${var.vpc_core_outputs.vpc_name}-private-primary"], var.vpc_core_outputs.subnet_ids["${var.vpc_core_outputs.vpc_name}-private-secondary"]]
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.cluster_service_ipv4_cidr
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,
    aws_cloudwatch_log_group.eks_cluster
  ]

  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_core_outputs.vpc_name}-${var.cluster_name}" }
  )
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_core_outputs.vpc_name}-${var.cluster_name}-cwlogs" }
  )
}

data "aws_iam_policy_document" "eks_cluster_assume_role_policy" {
  statement {
    sid     = "EKSClusterAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name                  = local.iam_role_name
  description           = "MyEKSCluster${title(var.cluster_name)}" #var.iam_role_description
  assume_role_policy    = data.aws_iam_policy_document.eks_cluster_assume_role_policy.json
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
            Resource = aws_cloudwatch_log_group.eks_cluster.arn
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
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  for_each = toset([
    "${local.policy_arn_prefix}/AmazonEKSClusterPolicy",
    "${local.policy_arn_prefix}/AmazonEKSVPCResourceController"
  ])
  policy_arn = each.value
  role       = aws_iam_role.eks_cluster.name
}


################################################################################
# IRSA
# Note - this is different from EKS identity provider
################################################################################

data "tls_certificate" "eks_cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_core_outputs.vpc_name}-${var.cluster_name}-eks-irsa" }
  )
}

data "aws_iam_policy_document" "federated_access" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
        type        = "Federated"
        identifiers = [aws_iam_openid_connect_provider.oidc_provider.arn]
      }
      condition {
        test     = var.assume_role_condition_test
        variable = "${replace("${aws_iam_openid_connect_provider.oidc_provider.arn}", "/^(.*provider/)/", "")}:aud"
        values   = ["sts.amazonaws.com"]
      }      
  }
}

resource "aws_iam_role" "federated_access" {
  name        = "MyEKSClusterFederatedAccess-${var.cluster_name}"
  description = "MyEKSClusterFederatedAccess-${var.cluster_name}"

  assume_role_policy    = data.aws_iam_policy_document.federated_access.json
  max_session_duration  = var.max_session_duration
  permissions_boundary  = var.role_permissions_boundary_arn
  force_detach_policies = var.force_detach_policies

  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "MyEKSClusterFederatedAccess-${var.cluster_name}" }
  )
}

resource "aws_iam_role_policy_attachment" "federated_access" {
  role       = aws_iam_role.federated_access.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

###########################################
## Install ArgoCD namespace
###########################################

data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}

provider "kubectl" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}

resource "kubectl_manifest" "argocd_namespace" {
    yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
    YAML
}

resource "kubectl_manifest" "argo_rollouts_namespace" {
    yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: argo-rollouts
    YAML
}


# data "kubectl_file_documents" "argocd" {
#     content = file("./manifests/argocd/install.yaml")
# } 

# resource "kubectl_manifest" "argocd" {
#     # count     = length(data.kubectl_file_documents.argocd.documents)
#     # yaml_body = element(data.kubectl_file_documents.argocd.documents, count.index)
#     # override_namespace = "argocd"
#         yaml_body = <<YAML
# apiVersion: kustomize.config.k8s.io/v1beta1
# kind: Kustomization
# namespace: argocd
# resources:
#   - https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.8/manifests/ha/install.yaml
#     YAML
#     override_namespace = "argocd"
# }

# provider "kustomization" {
#   kubeconfig_path = "C:/Users/usr/.kube/config"
# }

# data "kustomization" "test" {
#   provider = kustomization
#   #It will look for the file kustomization.yaml inside the folder
#   path = "./manifests/argocd/install"
# }

# resource "kustomization_resource" "test" {
#   provider = kustomization

#   for_each = data.kustomization.test.ids

#   manifest = data.kustomization.test.manifests[each.value]
# }

# resource "kubectl_manifest" "argocd" {
#     depends_on = [
#       kubectl_manifest.namespace,
#     ]
#     count     = length(data.kubectl_file_documents.argocd.documents)
#     yaml_body = element(data.kubectl_file_documents.argocd.documents, count.index)
#     override_namespace = "argocd"
# }

# module "example_custom_manifests" {
#   source  = "kbst.xyz/catalog/custom-manifests/kustomization"
#   version = "0.3.0"

#   configuration_base_key = "default"  # must match workspace name
#   configuration = {
#     default = {
#       namespace = "argocd"

#       resources = [
#         "./manifests/argocd/install.yaml"
#       ]
#     }
#   }
# }