provider "aws" {
  region = var.region
}

# Data source for AMI id
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create a VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# Create a Route Table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-route-table"
  }
}

# Create a Route for the Internet Gateway
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

# Create a Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_cidr_block
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Associate the Route Table with the Public Subnet
resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}

#----------------------------------------------
# Create a Security Group for the EC2 instance
resource "aws_security_group" "worker_node_sg" {
  name        = "worker-node-sg"
  description = "Security group for EC2 instance with open ports 8081, 8082, 8083, and 22"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all inbound traffic on port 8081
  }

  ingress {
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all inbound traffic on port 8082
  }

  ingress {
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all inbound traffic on port 8083
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access on port 22
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "worker-node-sg"
  }
}

#----------------------------------------------
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}


data "aws_iam_instance_profile" "existing_profile" {
  name = "LabInstanceProfile"
}

# EC2 Instance with the created key pair
resource "aws_instance" "worker_node" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.public_key  # make sure this public key exists in aws key pairs
  subnet_id              = aws_subnet.public_subnet.id  # Use the public subnet ID created above
  security_groups        = [aws_security_group.worker_node_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker git
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user

    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Clone GitHub repository (modify with your actual repo)
    git clone https://github.com/CLO835-Final-Project-Hamza-Behzad/clo835_final_project.git /home/ec2-user/app

    # Change ownership
    sudo chown -R ec2-user:ec2-user /home/ec2-user/app
  EOF

  tags = {
    Name = "WorkerNode"
  }
}