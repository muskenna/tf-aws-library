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

variable "eks_ng_secgrp_name" {
  description = "EKS Node Group Security Group Name"
  type        = string
}

variable "scaling_config_desired_size" {
  description = "EKS Node Group Security Group Name"
  type        = number
}

variable "scaling_config_max_size" {
  description = "EKS Node Group Security Group Name"
  type        = number
}

variable "scaling_config_min_size" {
  description = "EKS Node Group Security Group Name"
  type        = number
}

variable "node_group_name" {
  description = "EKS Node Group Security Group Name"
  type        = string
}



################################################################################
# Security Group
################################################################################

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

variable "eks_cluster_outputs" {
  type = object({
    cluster_name = string
  })
  description = "Security groups outputs"
}
