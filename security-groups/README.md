# Security Groups

Security groups are stateful. For example, if you send a request from an instance, the response traffic for that request is allowed to reach the instance regardless of the inbound security group rules. Responses to allowed inbound traffic are allowed to leave the instance, regardless of the outbound rules.

https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html

## Rules
### Source/Destination Types
The source types are CIDR, prefix, and security gateway id which include self and others sgs

https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules.html
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule<br/><br/>

## The property "source_security_group_name"


The sg property "source_security_group_id" is unknown initially. Therefore, the property "source_security_group_id" cannot be used directly in the terragrunt input.
Instead we need to reference the source/destination by name using a custom property called "source_security_group_name". In the example below, the sg "app-postgres-database" has a rule called "Postgres Port" referencing the sg "app" as you can see below.<br/><br/>

### Terragrunt Input Example
```
inputs = {
  security_groups = [
    {
      name = "ssh-access", group_desc = "SSH Access", rules = [
        { rule_desc = "SSH Access", direction = "ingress", from_port = "22", to_port = "22", protocol = "SSH", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false },
      { rule_desc = "Stateful access", direction = "egress", from_port = "0", to_port = "0", protocol = "all", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false }]
    },
    {
      name = "myapp-secure-web-access", group_desc = "MyApp Secure Web Access", rules = [
        { rule_desc = "HTTPS access", direction = "ingress", from_port = "443", to_port = "443", protocol = "HTTPS", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false },
      { rule_desc = "Stateful access", direction = "egress", from_port = "0", to_port = "0", protocol = "all", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false }]
    },
    {
      name = "postgresql-database-access", group_desc = "PostgreSQL Database Access", rules = [
        { rule_desc = "Default PostgreSQL Port", direction = "ingress", from_port = "5432", to_port = "5432", protocol = "tcp", cidr_blocks = [], source_security_group_name = "myapp-secure-web-access", self = false },
      { rule_desc = "Stateful access", direction = "egress", from_port = "0", to_port = "0", protocol = "all", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false }]
    },
  ]
}
```