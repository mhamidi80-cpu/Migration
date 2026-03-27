terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Using the latest stable AWS provider
    }
  }

  # --- Remote State Management ---
  # This matches the "Remote State" icon in your diagram
  backend "s3" {
    bucket         = "mhamidi80-migration-tf-state" # Replace with your unique bucket name
    key            = "migration/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"        # For state locking
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region # Managed in your variables.tf

  default_tags {
    tags = {
      Project     = "Hybrid-Migration"
      Owner       = "m.hamidi"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
