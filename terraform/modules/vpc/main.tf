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

# modules/compute/main.tf

# 1. Nginx/React Web Server (Public Subnet)
resource "aws_instance" "web_tier" {
  ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 (Verify AMI for your region)
  instance_type = "t3.micro"
  subnet_id     = var.public_subnet_id
  
  # Attach the Security Group and IAM Profile we created earlier
  vpc_security_group_ids = [var.web_sg_id]
  iam_instance_profile   = var.ssm_profile_name

  tags = {
    Name = "Migration-Web-Tier-Nginx"
  }
}

# 2. RDS Multi-AZ Database (Private Subnet)
resource "aws_db_subnet_group" "db_subnets" {
  name       = "migration-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "Migration-DB-Subnets" }
}

resource "aws_db_instance" "rds_primary" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.3"
  instance_class         = "db.t3.micro"
  multi_az               = true # High Availability as per diagram
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [var.db_sg_id]
  
  db_name                = "migrationdb"
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = true

  tags = { Name = "Migration-RDS-MultiAZ" }
}

variable "public_subnet_id" {}
variable "private_subnet_ids" { type = list(string) }
variable "web_sg_id" {}
variable "db_sg_id" {}
variable "ssm_profile_name" {}
variable "db_username" {}
variable "db_password" {}

# terraform/main.tf

module "networking" {
  source = "./modules/networking"
}

module "security" {
  source = "./modules/security"
  vpc_id = module.networking.vpc_id
}

module "compute" {
  source             = "./modules/compute"
  public_subnet_id   = module.networking.public_subnet_id
  private_subnet_ids = module.networking.private_subnet_ids
  web_sg_id          = module.security.web_sg_id
  db_sg_id           = module.security.app_sg_id # DB only talks to App SG
  ssm_profile_name   = module.security.ssm_profile_name
  db_username        = var.db_username
  db_password        = var.db_password
}


