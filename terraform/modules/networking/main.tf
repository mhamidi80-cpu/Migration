# terraform/modules/networking/main.tf

resource "aws_vpc" "migration_vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "Migration-Target-VPC" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.migration_vpc.id
  cidr_block        = "172.16.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "Public-Subnet-Web" }
}

resource "aws_ec2_transit_gateway" "tgw" {
  description = "Bridge to On-Prem 10.0.0.0/16"
  tags        = { Name = "Migration-TGW" }
}

# modules/security/main.tf

# Web Tier Security Group
resource "aws_security_group" "web_sg" {
  name        = "web-tier-sg"
  description = "Allow HTTP/HTTPS from Internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# App Tier Security Group (Private)
resource "aws_security_group" "app_sg" {
  name        = "app-tier-sg"
  description = "Allow traffic only from Web Tier"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ssm_role" {
  name = "Migration-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attach Amazon's SSM policy
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# The profile that gets attached to the EC2 instances
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "Migration-SSM-Instance-Profile"
  role = aws_iam_role.ssm_role.name
}

output "web_sg_id" {
  value = aws_security_group.web_sg.id
}

output "app_sg_id" {
  value = aws_security_group.app_sg.id
}

output "ssm_profile_name" {
  value = aws_iam_instance_profile.ssm_profile.name
}


