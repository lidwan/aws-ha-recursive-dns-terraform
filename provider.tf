terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.63.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

data "aws_region" "current" {
}

data "aws_availability_zones" "available" {
  state = "available"
}
