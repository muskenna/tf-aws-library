variable "account_id" {
  type        = string
  description = "AWS account id"
}

# variable "environment" {
#   type        = string
#   description = "Deployment environment"
# }

variable "region" {
  type        = string
  description = "Region terraform will run against"
}

# variable "vpc_name" {
#   type        = string
#   description = "The name of the VPC."
# }

# variable "deployments"{
#   type = map(map)
#   description = "Configuration for each deployment"
# }

variable "deployment" {
  type = object({
    account_id : string,
    environment : string,
    prefix : string,
    vpc_cidr_block : string,
    notes : list(string)
  })
  description = "Deployment configuration"
}


# variable "keypair_name" {
#   type        = string
#   description = "Region keypair"
# }
variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block for the VPC."
}

variable "deployment_tags" {
  type        = map(string)
  description = "Detault tags for all objects within a deployment (environment) that accept tags"
}

variable "subnet_config" {
  type        = list(map(string))
  description = "List of maps of common subnets for vpc"
}
