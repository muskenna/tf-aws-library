output "region" {
  value = var.region
}

output "vpc_name" {
  value = var.default_vpc_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr_block" {
  value = aws_vpc.main.cidr_block
}

# output "keypair_name" {
#   value = var.keypair_name
# }

output "subnet_ids" {
  value = local.subnet_ids
}