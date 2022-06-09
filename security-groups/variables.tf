
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

variable "vpc_outputs" {
  type = object({
    vpc_id = string
  })
  description = "VPC outputs"
}

variable "security_groups" {
  type = list(object({
    name       = string
    group_desc = string
    rules = list(object({
      rule_desc                  = string
      direction                  = string
      from_port                  = string
      to_port                    = string
      protocol                   = string
      cidr_blocks                = list(string)
      source_security_group_name = string
      self                       = bool
    }))
  }))
}