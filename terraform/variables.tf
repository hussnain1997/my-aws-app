variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project for tagging"
  type        = string
  default     = "ecs-project"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs/subnets to create (1-3)"
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be between 1 and 3."
  }
}

variable "subnet_newbits" {
  description = "New bits for subnet CIDR calculation"
  type        = number
  default     = 8
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {
    Environment = "dev"
    Project     = "ecs"
  }
}
