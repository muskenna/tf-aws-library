locals {
  all_sg_settings = { for settings in var.security_groups : "${settings.name}" => settings }
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


resource "aws_security_group" "all" {
  for_each    = local.all_sg_settings
  name        = each.value.name
  description = each.value.group_desc
  vpc_id      = var.vpc_outputs.vpc_id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = each.value.name }
  )
}

#Note
#The meaning variable prefix "sg_rules_src_dst"
#src = source
#dst = destination
locals {
  security_group_ids = { for config in aws_security_group.all : "${config.name}" => config.id }
  sg_rules_cidr = flatten([
    for sg_settings in local.all_sg_settings : [
      for rule in sg_settings["rules"] : {
        sg_name           = sg_settings.name
        description       = rule.rule_desc,
        type              = rule.direction,
        security_group_id = aws_security_group.all[sg_settings.name].id
        from_port         = rule.from_port,
        to_port           = rule.to_port,
        protocol          = rule.protocol,
        cidr_blocks       = rule.cidr_blocks,
      } if length(rule.cidr_blocks) > 0 && rule.source_security_group_name == "" && rule.self == false
    ]
  ])
  sg_rules_sg = flatten([
    for sg_settings in local.all_sg_settings : [
      for rule in sg_settings["rules"] : {
        sg_name                    = sg_settings.name
        description                = rule.rule_desc,
        type                       = rule.direction,
        security_group_id          = aws_security_group.all[sg_settings.name].id
        from_port                  = rule.from_port,
        to_port                    = rule.to_port,
        protocol                   = rule.protocol,
        source_security_group_name = rule.source_security_group_name,
      } if length(rule.cidr_blocks) == 0 && rule.source_security_group_name != "" && rule.self == false
    ]
  ])
  sg_rules_self = flatten([
    for sg_settings in local.all_sg_settings : [
      for rule in sg_settings["rules"] : {
        sg_name           = sg_settings.name
        description       = rule.rule_desc,
        type              = rule.direction,
        security_group_id = aws_security_group.all[sg_settings.name].id
        from_port         = rule.from_port,
        to_port           = rule.to_port,
        protocol          = rule.protocol,
        self              = rule.self
      } if length(rule.cidr_blocks) == 0 && rule.source_security_group_name == "" && rule.self == true
    ]
  ])

  #To be implemented
  # sg_rules_prefix = flatten([
  #   for sg_settings in local.all_sg_settings : [
  #     for rule in sg_settings["rules"] : {
  #       sg_name           = sg_settings.name
  #       description       = rule.rule_desc,
  #       type              = rule.direction,
  #       security_group_id = aws_security_group.all[sg_settings.name].id
  #       from_port         = rule.from_port,
  #       to_port           = rule.to_port,
  #       protocol          = rule.protocol,
  #       prefix_list_ids   = rule.prefix_ids
  #     } #if length(rule.cidr_blocks) == 0 && rule.source_security_group_name == "" && rule.self == true
  #   ]
  # ])  
}

resource "aws_security_group_rule" "all_cidr_source" {
  for_each          = { for rule in local.sg_rules_cidr : "${rule.sg_name}-${rule.description}" => rule }
  description       = each.value.description
  type              = each.value.type
  security_group_id = each.value.security_group_id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}

resource "aws_security_group_rule" "all_sg_source" {
  for_each                 = { for rule in local.sg_rules_sg : "${rule.sg_name}-${rule.description}" => rule }
  description              = each.value.description
  type                     = each.value.type
  security_group_id        = each.value.security_group_id
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = aws_security_group.all[each.value.source_security_group_name].id
}

resource "aws_security_group_rule" "all_self_source" {
  for_each          = { for rule in local.sg_rules_self : "${rule.sg_name}-${rule.description}" => rule }
  description       = each.value.description
  type              = each.value.type
  security_group_id = each.value.security_group_id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  self              = each.value.self
}