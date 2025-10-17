# Fetch latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Fetch available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "myvpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = var.vpc_name
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.public_subnet_name}-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  tags = {
    Name = "${var.private_subnet_name}-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name = var.igw_name
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = var.public_rt_name
  }
}

# Associate Route Table
resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public_subnet)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for EC2 (Presentation Tier)
resource "aws_security_group" "ec2_sg" {
  name        = var.ec2_sg_name
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Tighten to your IP for security
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = var.ec2_sg_name
  }
}

# Security Group for Application Tier
resource "aws_security_group" "app_sg" {
  name        = var.app_sg_name
  description = "Allow Flask port 5002"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    from_port   = 5002
    to_port     = 5002
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = var.app_sg_name
  }
}

# Security Group for Aurora RDS
resource "aws_security_group" "rds_sg" {
  name        = var.rds_sg_name
  description = "Allow MySQL port 3306"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = var.rds_sg_name
  }
}

# Generate private key
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair
resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.ec2_instance_name}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Store private key in S3
resource "aws_s3_object" "private_key" {
  bucket  = var.key_pair_bucket
  key     = "keys/${var.ec2_instance_name}-key.pem"
  content = tls_private_key.ec2_key.private_key_pem
  acl     = "private"
}

# IAM Role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "SSMRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attach SSM Policy
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile for SSM
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "SSMProfile"
  role = aws_iam_role.ssm_role.name
}

# EC2 Instance (Combined Presentation and Application Tiers)
resource "aws_instance" "ec2_instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnet[0].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id, aws_security_group.app_sg.id]
  key_name      = aws_key_pair.ec2_key.key_name
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  user_data     = <<-EOF
                  #!/bin/bash
                  yum update -y
                  yum install -y docker
                  systemctl start docker
                  systemctl enable docker
                  usermod -aG docker ec2-user
                  docker run -d -p 3000:3000 my-front
                  docker run -d -p 5002:5002 back-app
                  EOF
  tags = {
    Name = var.ec2_instance_name
  }
}

# Secrets Manager for Aurora Credentials
resource "aws_secretsmanager_secret" "aurora_credentials" {
  name = "${var.aurora_cluster_identifier}-credentials"
}

resource "aws_secretsmanager_secret_version" "aurora_credentials_version" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id
  secret_string = jsonencode({
    username = var.aurora_master_username
    password = var.aurora_master_password
  })
}

# IAM Policy for EC2 to Access Secrets Manager
resource "aws_iam_role_policy" "secrets_manager_access" {
  name = "SecretsManagerAccess"
  role = aws_iam_role.ssm_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = aws_secretsmanager_secret.aurora_credentials.arn
    }]
  })
}

# Aurora RDS Cluster
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = var.aurora_cluster_identifier
  engine                  = "aurora-mysql"
  engine_version          = var.aurora_engine_version
  master_username         = jsondecode(aws_secretsmanager_secret_version.aurora_credentials_version.secret_string)["username"]
  master_password         = jsondecode(aws_secretsmanager_secret_version.aurora_credentials_version.secret_string)["password"]
  database_name           = var.aurora_database_name
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
}

# DB Subnet Group for Aurora
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = var.db_subnet_group_name
  subnet_ids = aws_subnet.private_subnet[*].id
  tags = {
    Name = var.db_subnet_group_name
  }
}
