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

output "subnet_ids" {
  value = local.subnet_ids
}

output "default_key_pair_name" {
  value = aws_key_pair.default_key_pair.key_name
}

