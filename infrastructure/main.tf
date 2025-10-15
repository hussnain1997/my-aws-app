provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyAppVPC"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1e"
  tags = {
    Name = "PublicSubnet"
  }
}

# Private Subnet (First AZ)
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1e"
  tags = {
    Name = "PrivateSubnet"
  }
}

# Private Subnet (Second AZ)
resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"  // Different AZ
  tags = {
    Name = "PrivateSubnet2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name = "MyAppIGW"
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
    Name = "PublicRouteTable"
  }
}

# Associate Route Table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for EC2 (Presentation Tier)
resource "aws_security_group" "ec2_sg" {
  name        = "EC2SecurityGroup"
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
    cidr_blocks = ["0.0.0.0/0"]  // Tighten to your IP for security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "EC2SG"
  }
}

# Security Group for Application Tier EC2
resource "aws_security_group" "app_sg" {
  name        = "AppSecurityGroup"
  description = "Allow Flask port 5002"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port   = 5002
    to_port     = 5002
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]  // Allow SSH from presentation_ec2
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "AppSG"
  }
}

# Security Group for Aurora RDS
resource "aws_security_group" "rds_sg" {
  name        = "RDSSecurityGroup"
  description = "Allow MySQL port 3306"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]  // Allow from Application EC2
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "RDSSG"
  }
}

# Presentation Tier EC2 (Public)
resource "aws_instance" "presentation_ec2" {
  ami           = "ami-052064a798f08f0d3"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name      = "my-ec2-key"  // Verify this matches your AWS key pair
  user_data     = <<-EOF
                 #!/bin/bash
                 sudo yum update -y
                 sudo yum install docker -y
                 sudo systemctl start docker
                 sudo systemctl enable docker
                 sudo usermod -aG docker ec2-user
                 sudo docker run -d -p 3000:3000 my-front
                 EOF
  tags = {
    Name = "PresentationEC2"
  }
}

# Application Tier EC2 (Private) with IAM Profile
resource "aws_instance" "application_ec2" {
  ami           = "ami-052064a798f08f0d3"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name      = "my-ec2-key"  // Verify this matches your AWS key pair
  user_data     = <<-EOF
                 #!/bin/bash
                 sudo yum update -y
                 sudo yum install docker -y
                 sudo systemctl start docker
                 sudo systemctl enable docker
                 sudo usermod -aG docker ec2-user
                 sudo docker run -d -p 5002:5002 back-app
                 EOF
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name  // Added for SSM
  tags = {
    Name = "ApplicationEC2"
  }
}

# Aurora RDS (Serverless)
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "my-aurora-cluster"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.08.2"
  master_username         = "admin"
  master_password         = "MySecurePass2025!"  // Ensure this is secure
  database_name           = "mydata"
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
}

# DB Subnet Group for Aurora
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.private_subnet_2.id]
  tags = {
    Name = "MyDBSubnetGroup"
  }
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

# Attach SSM Policy to Role
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile for SSM
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "SSMProfile"
  role = aws_iam_role.ssm_role.name
}
