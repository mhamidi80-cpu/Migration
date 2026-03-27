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
