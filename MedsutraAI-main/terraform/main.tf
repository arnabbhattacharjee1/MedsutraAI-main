# Main Terraform configuration for AI Cancer Detection Platform
# This file sets up the VPC, subnets, and networking infrastructure

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Backend configuration should be provided via backend config file
    # terraform init -backend-config=backend.tfvars
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "AI-Cancer-Detection"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
