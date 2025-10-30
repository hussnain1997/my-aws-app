terraform {
  required_version = ">= 1.0.0"
  backend "s3" {
    bucket         = var.tf_state_bucket
    key            = "terraform/state/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table
  }
}
