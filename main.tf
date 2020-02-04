# Specify Provider Details
provider "aws" {
  profile = "default"
  region  = "us-east-2"
}

# Create VPC with IpV4 Class A CIDR block of 64 IPs
resource "aws_vpc" "terraform_vpc_basic" {
  cidr_block           = "10.0.0.0/26"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

}

# Create an internet gateway (virtual router that connects a VPC to the internet)
resource "aws_internet_gateway" "terraform_vpc_basic_igt" {
  vpc_id = aws_vpc.terraform_vpc_basic.id
}

# Route table specifies how packets are forwarded b/w subnets within your VPC, the internet and VPN connection
# Create a Public Route table associated with custom VPC and allow IpV4 traffic on Internet Gateway
resource "aws_route_table" "terraform_vpc_basic_public_rt" {
  vpc_id = aws_vpc.terraform_vpc_basic.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_vpc_basic_igt.id
  }
}

################################ Public Subnet Starts ###############################
# Create a public subnet , ensure map_public_ip_on_launch is set to true
resource "aws_subnet" "terraform_vpc_basic_public_sn" {
  vpc_id                  = aws_vpc.terraform_vpc_basic.id
  cidr_block              = "10.0.0.0/28"
  availability_zone_id    = "use2-az1"
  map_public_ip_on_launch = true
}

# Associate subnet with a internet gateway route
resource "aws_route_table_association" "terraform_vpc_basic_public_sn_route" {
  subnet_id      = aws_subnet.terraform_vpc_basic_public_sn.id
  route_table_id = aws_route_table.terraform_vpc_basic_public_rt.id
}

# Generate an Elastic IP
resource "aws_eip" "terraform_vpc_basic_public_sn_ng_elastic_ip" {
}

# Create a Network Address Translation (NAT) Gateway on Public Subnet
# Associate to Public Subnet & an Elastic IP Address
resource "aws_nat_gateway" "terraform_vpc_basic_public_sn_ng" {
  allocation_id = aws_eip.terraform_vpc_basic_public_sn_ng_elastic_ip.id
  subnet_id     = aws_subnet.terraform_vpc_basic_public_sn.id
}
################################ Public Subnet Ends ###############################

################################ Private Subnet Starts ###############################
# Create a private subnet
resource "aws_subnet" "terraform_vpc_basic_private_sn" {
  vpc_id               = aws_vpc.terraform_vpc_basic.id
  cidr_block           = "10.0.0.16/28"
  availability_zone_id = "use2-az1"
}

# Create a Private Route table
resource "aws_route_table" "terraform_vpc_basic_private_rt" {
  vpc_id = aws_vpc.terraform_vpc_basic.id
}

# Add a Route in Private Route Table to allow IpV4 traffic using route to NAT Gateway 
resource "aws_route" "terraform_vpc_basic_private_sn_internet_access" {
  route_table_id         = aws_route_table.terraform_vpc_basic_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.terraform_vpc_basic_public_sn_ng.id
}

# Associate subnet with a internet gateway route
resource "aws_route_table_association" "terraform_vpc_basic_private_sn_route" {
  subnet_id      = aws_subnet.terraform_vpc_basic_private_sn.id
  route_table_id = aws_route_table.terraform_vpc_basic_private_rt.id
}

################################ Private Subnet Ends ###############################

# Create a security group to allow web traffic to/from instances running on private / public subnets in our custom VPC
resource "aws_security_group" "terraform_vpc_basic_webserver_sg" {
  name        = "terraform_vpc_basic_webserver_sg"
  description = "Allow SSH & HTTP inbound traffic"
  vpc_id      = aws_vpc.terraform_vpc_basic.id

  # SSH 
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP 
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Create an EC2 Instance in Private Subnet with NO Public IP 
# Associate to your key_name 
resource "aws_instance" "webapp" {
  ami                         = "ami-04216cece22bda12d"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.terraform_vpc_basic_private_sn.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.terraform_vpc_basic_webserver_sg.id]
  key_name                    = "ssh1"

}

# Create a Classic Load Balancer configure on public subnet of VPC
# A listener is a process that checks for connection requests. It is configured with a protocol and a port for front-end (client to load balancer) connections and a protocol and a port for back-end (load balancer to instance) connections.
resource "aws_elb" "terraform_vpc_basic_classic_lb" {
  name            = "classic-load-balancer"
  subnets         = [aws_subnet.terraform_vpc_basic_public_sn.id]
  security_groups = [aws_security_group.terraform_vpc_basic_webserver_sg.id]

  listener {
    instance_port     = 22
    instance_protocol = "tcp"
    lb_port           = 22
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 80
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }

  instances = [aws_instance.webapp.id]

  health_check {
    healthy_threshold   = 10
    unhealthy_threshold = 2
    timeout             = 5
    target              = "TCP:22"
    interval            = 30
  }
}
################################ Provision Remote EC2 Instance ###############################
# Connect to Private EC2 Instance as ec2-user using Elastic Load Balancer DNS name backed by Public IP
# Provision remote EC2 Instance as root user to start HTTP Server which will be used for static Web App 
# Ensure to use correct Private Key from associated key_name of EC2 instance
resource "null_resource" "provision_ec2" {
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/ssh1.pem")
    host        = aws_elb.terraform_vpc_basic_classic_lb.dns_name
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd"
    ]
  }

  depends_on = [aws_nat_gateway.terraform_vpc_basic_public_sn_ng, aws_elb.terraform_vpc_basic_classic_lb, aws_instance.webapp]
}

# Connect to private EC2 instance and provision Web Server to use custom HTML code 
resource "null_resource" "provision_ec2_webApp" {
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/ssh1.pem")
    host        = aws_elb.terraform_vpc_basic_classic_lb.dns_name
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chown -R ec2-user /var/www/html",
      "sudo chmod -R 755 /var/www/html",
      "sudo su -c \"echo \\\"<html><body bgcolor='red'><h1>Welcome to Web App | Basic VPC build by Terraform</h2></body></html>\\\"\" >  /var/www/html/index.html"
    ]
  }

  depends_on = [null_resource.provision_ec2, aws_elb.terraform_vpc_basic_classic_lb]
}

# Validate our code is running fine on remote instance,Open web page on local client host 
resource "null_resource" "open_webapp" {
  provisioner "local-exec" {
    command     = "start http://${aws_elb.terraform_vpc_basic_classic_lb.dns_name}"
    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [null_resource.provision_ec2, null_resource.provision_ec2_webApp, aws_elb.terraform_vpc_basic_classic_lb]
}