terraform {
  required_version = ">= 1.5"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    random  = { source = "hashicorp/random", version = "~> 3.5" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
  # Recommended for teams: remote state (create the bucket + lock table first)
  # backend "s3" { bucket = "<state-bucket>" key = "cloudops/terraform.tfstate" region = "ap-south-1" dynamodb_table = "tf-lock" encrypt = true }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = local.tags }
}
