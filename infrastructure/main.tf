# VPC
resource "aws_vpc" "myvpc" {
  cidr_block = var.vpc_cidr
  tags = merge(var.tags, {
    Name = "${var.tags.project}-VPC"
  })
}

# Subnets
resource "aws_subnet" "subnets" {
  for_each = { for idx, config in var.subnet_configs : idx => config }

  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.public
  tags = merge(var.tags, {
    Name = "${var.tags.project}-${each.value.public ? "Public" : "Private"}-Subnet-${each.key + 1}"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
  tags = merge(var.tags, {
    Name = "${var.tags.project}-IGW"
  })
}

# Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(var.tags, {
    Name = "${var.tags.project}-Public-RouteTable"
  })
}

# Associate Route Table with Public Subnet
resource "aws_route_table_association" "public_assoc" {
  for_each = { for idx, config in var.subnet_configs : idx => config if config.public }

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "${var.tags.project}-EC2-SG"
  description = "Allow HTTP, Flask, and SSH"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5002
    to_port     = 5002
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Tighten to your IP for production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, {
    Name = "${var.tags.project}-EC2-SG"
  })
}

# Security Group for Aurora RDS
resource "aws_security_group" "rds_sg" {
  name        = "${var.tags.project}-RDS-SG"
  description = "Allow MySQL port 3306"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, {
    Name = "${var.tags.project}-RDS-SG"
  })
}

# EC2 Instance (Single instance for both tiers)
resource "aws_instance" "app_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = [for subnet in aws_subnet.subnets : subnet.id if subnet.map_public_ip_on_launch][0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
              docker run -d -p 3000:3000 my-front
              docker run -d -p 5002:5002 back-app
              EOF
  tags = merge(var.tags, {
    Name = "${var.tags.project}-App-EC2"
  })
}

# Aurora RDS (Serverless)
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = var.rds_cluster_identifier
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.08.2"
  master_username         = var.rds_username
  master_password         = jsondecode(aws_secretsmanager_secret_version.rds_password_version.secret_string).password
  database_name           = var.rds_database_name
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
}

# DB Subnet Group for Aurora
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.tags.project}-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.subnets : subnet.id if !subnet.map_public_ip_on_launch]
  tags = merge(var.tags, {
    Name = "${var.tags.project}-DB-Subnet-Group"
  })
}

# IAM Role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "${var.tags.project}-SSM-Role"
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
  name = "${var.tags.project}-SSM-Profile"
  role = aws_iam_role.ssm_role.name
}

# Generate Key Pair
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Store Key Pair in S3
resource "aws_s3_object" "private_key" {
  bucket = "my-ec2-key-bucket"
  key    = "ec2-key.pem"
  content = tls_private_key.ec2_key.private_key_pem
}
