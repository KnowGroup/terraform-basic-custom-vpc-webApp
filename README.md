# Basic VPC Design - Build using Terraform
      Make a basic custom VPC with a single Private and Public Subnet, loaded with an Internet and NAT Gateway using Terraform Script (infrastructure as code), Also Setup private and public routes and a security group to allow ipV4 traffic on port 22 &amp; 80. Further Provision and launch the static website running on the private EC2 instance using Elastic Load Balancer DNS name.

# VPC cidr IpV4 Class A CIRD (Classless interdomain routing) 
	# VPC IP range :
     10.0.0.0/26
	   64 IPs
	# Public Subnet cidr :
	   10.0.0.0/28
	   16 - 5 (11) IPs
	# Private Subnet cidr :
	   10.0.0.16/28
	   16 - 5 (11)
# private_key name : ssh1.pem
    - file("~/.ssh/ssh1.pem")
# Terraform Commands
    #  First command to run for a new configuration
	      terraform init
    > terraform fmt
    > terraform validate
    > terraform apply
    > terraform destroy

# Further Read :
    > https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html#VPC_Sizing
    > aws_internet_gateway : https://www.terraform.io/docs/providers/aws/r/internet_gateway.html
    > aws_route_table : https://www.terraform.io/docs/providers/aws/r/route_table.html
    > aws_subnet : https://www.terraform.io/docs/providers/aws/r/subnet.html
    > aws_route_table_association : https://www.terraform.io/docs/providers/aws/r/route_table_association.html
    > aws_nat_gateway : https://www.terraform.io/docs/providers/aws/r/nat_gateway.html
    > aws_eip.nat.id : https://www.terraform.io/docs/providers/aws/r/eip.html
    > aws_route : https://www.terraform.io/docs/providers/aws/r/route.html#nat_gateway_id
    > aws_network_acl : https://www.terraform.io/docs/providers/aws/r/network_acl.html
    > aws_security_group : https://www.terraform.io/docs/providers/aws/r/security_group.html
    > aws_elb (classic): https://www.terraform.io/docs/providers/aws/r/elb.html
    > local-exec: https://www.terraform.io/docs/provisioners/local-exec.html
    > remote-exec: https://www.terraform.io/docs/provisioners/remote-exec.html
    > https://cidr.xyz/
