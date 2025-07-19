terraform {
  backend "s3" {
    bucket         = "argocd-proj-terraform-state-storage"

    region         = "us-east-1"
    
    key            = "argocd-proj-terraform-state-storage/terraform.tfstate"
    
    dynamodb_table = "lock-files"
    
    encrypt        = true
  }

  required_version = ">=0.13.0"

  required_providers {
    aws = {
  
      version = ">= 2.7.0"
      
    
      source  = "hashicorp/aws"
    }
  }
}