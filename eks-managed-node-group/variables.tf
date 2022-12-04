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

variable "max_unavailable" {
  description = "Number of days to retain log events. Default retention - 90 days"
  type        = number
  default     = 2
}

variable "max_unavailable_percentage" {
  description = "Number of days to retain log events. Default retention - 90 days"
  type        = number
  default     = null
}


################################################################################
# Security Group
################################################################################

variable "node_group_remote_access_security_group_name" {
  description = "Security Group Name for EKS Node Group Remote Access"
  type        = string
}

variable "scaling_config_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "scaling_config_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
}

variable "scaling_config_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
}

variable "node_group_name" {
  description = "Name of the EKS Node Group"
  type        = string
}

variable "ami_release_version" {
  description = "AMI version of the EKS Node Group. Defaults to latest version for Kubernetes version"
  type        = string
}

variable "ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group"
  type        = string
  #https://aws.amazon.com/bottlerocket/faqs/
  default = "BOTTLEROCKET_x86_64"
}

variable "instance_types" {
  description = "List of instance types associated with the EKS Node Group"
  type        = list(string)
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group. Valid values: ON_DEMAND, SPOT"
  type        = string
}

variable "kube_version" {
  description = "Kubernetes version"
  type        = string
}

################################################################################
# Security Group
################################################################################

variable "vpc_core_outputs" {
  type = object({
    vpc_name              = string
    default_key_pair_name = string
    subnet_ids            = map(string)
  })
  description = "VPC outputs"
}

variable "security_groups_outputs" {
  type = object({
    security_group_ids = map(string)
  })
  description = "Security groups outputs"
}

variable "eks_cluster_outputs" {
  type = object({
    cluster_name = string
    endpoint = string
    ca_certificate = string
  })
  description = "Security groups outputs"
}
