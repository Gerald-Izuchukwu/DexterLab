terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Intentionally left as local state for this exercise.
  # In production this would be an S3 backend with a DynamoDB lock table:
  #
  # backend "s3" {
  #   bucket         = "dexter-wallet-tfstate"
  #   key            = "wallet-backend/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "dexter-wallet-tf-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "dexter-wallet-backend"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
