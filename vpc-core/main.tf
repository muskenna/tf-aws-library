locals {
  public_subnets_config  = { for config in var.subnet_config : "${config.name}-${config.route}-${config.az_type}" => config if config.route == "public" }
  private_subnets_config = { for config in var.subnet_config : "${config.name}-${config.route}-${config.az_type}" => config if config.route == "private" }
  subnet_config          = { for config in var.subnet_config : "${config.name}-${config.route}-${config.az_type}" => config }
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

#The ec2 key pair must be created manually. This is a requirement before executing Terraform deployments
# Check the readme.md file for more details
# data "aws_key_pair" "vpc" {
#   key_name = var.keypair_name
# }

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = "true"
  enable_dns_hostnames = "true" # Enable public DNS hostnames for Public IP addresses - Required for VPC Endpoints.
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = var.default_vpc_name
    }
  )
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zone_post_fixes = [for name in data.aws_availability_zones.available.names : substr(name, length(name) - 1, length(name))]
  availability_zones           = zipmap(["primary", "secondary"], slice(data.aws_availability_zones.available.names, 0, 2))
}
resource "aws_subnet" "subnets" {
  for_each          = local.subnet_config
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, each.value.newbits, each.value.netnum)
  availability_zone = lower(each.value.az_type) == "primary" ? "${local.availability_zones["primary"]}" : "${local.availability_zones["secondary"]}"
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "${each.value.name}-${each.value.route}-${each.value.az_type}"
    }
  )
}

locals {
  public_subnet_ids  = { for config in var.subnet_config : "${config.name}-${config.route}-${config.az_type}" => aws_subnet.subnets["${config.name}-${config.route}-${config.az_type}"].id if config.route == "public" }
  private_subnet_ids = { for config in var.subnet_config : "${config.name}-${config.route}-${config.az_type}" => aws_subnet.subnets["${config.name}-${config.route}-${config.az_type}"].id if config.route == "private" }
  subnet_ids = { for config in var.subnet_config :
  "${config.name}-${config.route}-${config.az_type}" => aws_subnet.subnets["${config.name}-${config.route}-${config.az_type}"].id }
}
resource "aws_internet_gateway" "vpc_internet_gateway" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = var.default_vpc_name
    }
  )
}

resource "aws_eip" "primary" {
  vpc = true
}

resource "aws_eip" "secondary" {
  vpc = true
}

resource "aws_nat_gateway" "public_primary" {
  allocation_id = aws_eip.primary.id
  subnet_id     = local.public_subnet_ids["main-public-primary"]
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "main-public-primary"
    }
  )
  depends_on = [aws_internet_gateway.vpc_internet_gateway]
}

resource "aws_nat_gateway" "public_secondary" {
  allocation_id = aws_eip.secondary.id
  subnet_id     = local.public_subnet_ids["main-public-secondary"]
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "main-public-secondary"
    }
  )
  depends_on = [aws_internet_gateway.vpc_internet_gateway]
}

## Routing tables

# Public route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "main-public"
    }
  )
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vpc_internet_gateway.id
}

# Private route
resource "aws_route_table" "private_primary" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "main-private-primary"
    }
  )
}

resource "aws_route" "private_primary" {
  route_table_id         = aws_route_table.private_primary.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public_primary.id
}

resource "aws_route_table" "private_secondary" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "main-private-secondary"
    }
  )
}

resource "aws_route" "private_secondary" {
  route_table_id         = aws_route_table.private_secondary.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public_secondary.id
}

#Using one route table for both public subnet since they point to the same internet gateway
resource "aws_route_table_association" "public" {
  for_each       = { for k, v in local.public_subnets_config : k => v }
  subnet_id      = local.subnet_ids["${each.value.name}-${each.value.route}-${each.value.az_type}"]
  route_table_id = aws_route_table.public.id
}

#Using separate route table for private subnets since they point to different NAT Gateways
resource "aws_route_table_association" "private_primary" {
  subnet_id      = local.subnet_ids["main-private-primary"]
  route_table_id = aws_route_table.private_primary.id
}

resource "aws_route_table_association" "private_secondary" {
  subnet_id      = local.subnet_ids["main-private-secondary"]
  route_table_id = aws_route_table.private_secondary.id
}


resource "tls_private_key" "instance" {
  algorithm = "RSA"
}

resource "aws_key_pair" "default_key_pair" {
  key_name   = "default-${var.default_vpc_name}"
  public_key = tls_private_key.instance.public_key_openssh
  tags = {
    Name = "default-${var.default_vpc_name}"
  }
}

resource "aws_secretsmanager_secret" "default_key_pair" {
  name = "ec2/keypair/default-${var.default_vpc_name}"
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.default_key_pair.id
  secret_string = tls_private_key.instance.private_key_pem
}