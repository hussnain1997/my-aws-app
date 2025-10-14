provider "aws" {
  region = "us-east-1"
}

// VPC
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyAppVPC"
  }
}

// Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true  // Allows EC2 to get a public IP
  tags = {
    Name = "PublicSubnet"
  }
}

// Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "PrivateSubnet"
  }
}

// Internet Gateway for public access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name = "MyAppIGW"
  }
}

// Route Table for Public Subnet
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

// Associate Route Table with Public Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

// Security Group for EC2 (Presentation Tier)
resource "aws_security_group" "ec2_sg" {
  name        = "EC2SecurityGroup"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  // Allow web access (tighten later)
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  // Allow SSH (tighten later)
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

// Security Group for Application Tier EC2
resource "aws_security_group" "app_sg" {
  name        = "AppSecurityGroup"
  description = "Allow Flask port 5002"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port   = 5002
    to_port     = 5002
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  // Allow only within VPC
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

// Security Group for Aurora RDS
resource "aws_security_group" "rds_sg" {
  name        = "RDSSecurityGroup"
  description = "Allow MySQL port 3306"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  // Allow only within VPC
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

// Presentation Tier EC2 (Public)
resource "aws_instance" "presentation_ec2" {
  ami           = "ami-0c55b159cbfafe1f0"  // Amazon Linux 2 AMI (update for your region)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name      = "your-key-pair"  // Replace with your SSH key name
  user_data     = <<-EOF
                  #!/bin/bash
                  sudo yum update -y
                  sudo yum install docker -y
                  sudo systemctl start docker
                  sudo systemctl enable docker
                  sudo usermod -aG docker ec2-user
                  sudo docker run -d -p 3000:3000 my-front  // Adjust image name
                  EOF
  tags = {
    Name = "PresentationEC2"
  }
}

// Application Tier EC2 (Private)
resource "aws_instance" "application_ec2" {
  ami           = "ami-0c55b159cbfafe1f0"  // Amazon Linux 2 AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name      = "your-key-pair"  // Replace with your SSH key name
  user_data     = <<-EOF
                  #!/bin/bash
                  sudo yum update -y
                  sudo yum install docker -y
                  sudo systemctl start docker
                  sudo systemctl enable docker
                  sudo usermod -aG docker ec2-user
                  sudo docker run -d -p 5002:5002 back-app  // Adjust image name
                  EOF
  tags = {
    Name = "ApplicationEC2"
  }
}

// Aurora RDS (Serverless)
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "my-aurora-cluster"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3"
  master_username         = "admin"
  master_password         = "AuroraPass123"  // Change to a secure password
  database_name           = "mydata"
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
}

// DB Subnet Group for Aurora
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet.id]
  tags = {
    Name = "MyDBSubnetGroup"
  }
}