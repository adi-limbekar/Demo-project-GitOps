terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.59.0"
    }
  }
}

provider "aws" {
  access_key = "test"
  secret_key = "test"
  region     = "us-east-1"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    eks            = "http://localhost:4566"
    ecr            = "http://localhost:4566"
    s3             = "http://localhost:4566"
    rds            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}

