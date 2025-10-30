variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "tf_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
  default     = "my-terraform-state-bucket"
}

variable "tf_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  type        = string
  default     = "terraform-lock-table"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
  default     = "MyAppVPC"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_name" {
  description = "Name tag for the public subnet"
  type        = string
  default     = "PublicSubnet"
}

variable "private_subnet_name" {
  description = "Name tag for the private subnets"
  type        = string
  default     = "PrivateSubnet"
}

variable "igw_name" {
  description = "Name tag for the Internet Gateway"
  type        = string
  default     = "MyAppIGW"
}

variable "public_rt_name" {
  description = "Name tag for the public route table"
  type        = string
  default     = "PublicRouteTable"
}

variable "ec2_sg_name" {
  description = "Name tag for the EC2 security group"
  type        = string
  default     = "EC2SG"
}

variable "app_sg_name" {
  description = "Name tag for the application security group"
  type        = string
  default     = "AppSG"
}

variable "rds_sg_name" {
  description = "Name tag for the RDS security group"
  type        = string
  default     = "RDSSG"
}

variable "db_subnet_group_name" {
  description = "Name for the DB subnet group"
  type        = string
  default     = "MyDBSubnetGroup"
}

variable "aurora_cluster_identifier" {
  description = "Identifier for the Aurora cluster"
  type        = string
  default     = "my-aurora-cluster"
}

variable "aurora_master_username" {
  description = "Master username for Aurora"
  type        = string
  default     = "admin"
}

variable "aurora_master_password" {
  description = "Master password for Aurora (stored in Secrets Manager)"
  type        = string
  sensitive   = true
  default     = "MySecurePass2025!"
}

variable "aurora_engine_version" {
  description = "Aurora MySQL engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.08.2"
}

variable "aurora_database_name" {
  description = "Name of the initial database"
  type        = string
  default     = "mydata"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ec2_instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "AppEC2"
}

variable "key_pair_bucket" {
  description = "S3 bucket to store EC2 private key"
  type        = string
  default     = "my-key-pair-bucket"
}
