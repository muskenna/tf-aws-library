variable "account_id" {
  type        = string
  description = "AWS account id"
}

variable "region" {
  type        = string
  description = "Region terraform will run against"
}

variable "deployment_tags" {
  type        = map(string)
  description = "Detault tags for all objects within a deployment (environment) that accept tags"
}

################################################################################
# Cluster
################################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = ""
}

variable "cluster_version" {
  description = "Kubernetes `<major>.<minor>` version to use for the EKS cluster (i.e.: `1.22`)"
  type        = string
  default     = null
}

variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html)"
  type        = list(string)
  default     = ["audit", "api", "authenticator"]
}

variable "cluster_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_service_ipv4_cidr" {
  description = "The CIDR block to assign Kubernetes service IP addresses from. If you don't specify a block, Kubernetes assigns addresses from either the 10.100.0.0/16 or 172.20.0.0/16 CIDR blocks"
  type        = string
  default     = null
}

# variable "cluster_timeouts" {
#   description = "Create, update, and delete timeout configurations for the cluster"
#   type        = map(string)
#   default     = {}
# }

################################################################################
# Security Group
################################################################################

variable "eks_secgrp_name" {
  description = "EKS Security Group Name"
  type        = string
}

################################################################################
# KMS Key
################################################################################

#...For future use

################################################################################
# CloudWatch Log Group
################################################################################

variable "create_cloudwatch_log_group" {
  description = "Determines whether a log group is created by this module for the cluster logs. If not, AWS will automatically create one if logging is enabled"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain log events. Default retention - 90 days"
  type        = number
  default     = 90
}

# variable "cloudwatch_log_group_kms_key_id" {
#   description = "If a KMS Key ARN is set, this key will be used to encrypt the corresponding log group. Please be sure that the KMS Key has an appropriate key policy (https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html)"
#   type        = string
#   default     = null
# }

variable "vpc_core_outputs" {
  type = object({
    vpc_name     = string
    subnet_ids   = map(string)
  })
  description = "VPC outputs"
}

variable "security_groups_outputs" {
  type = object({
    security_group_ids = map(string)
  })
  description = "Security groups outputs"
}


