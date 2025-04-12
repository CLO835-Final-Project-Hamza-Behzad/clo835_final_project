# Data source for AMI id
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Fetch existing VPC by filtering with a known tag or name
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["main-vpc"]
  }
}


# Fetch existing Security Group by name
data "aws_security_group" "existing_sg" {
  filter {
    name   = "group-name"
    values = ["worker-node-sg"]
  }
  vpc_id = data.aws_vpc.existing.id
}

# Fetch existing subnet (modify filter as needed)
data "aws_subnet" "existing_public_subnet" {
  filter {
    name   = "tag:Name"
    values = ["public-subnet"]
  }
  vpc_id = data.aws_vpc.existing.id
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# resource "aws_iam_instance_profile" "lab_instance_profile" {
#   name = "LabInstanceProfile"
#   role = data.aws_iam_role.lab_role.name
# }

data "aws_iam_instance_profile" "existing_profile" {
  name = "LabInstanceProfile"
}


# EC2 Instance with existing resources
resource "aws_instance" "worker_node" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = "ec2_key"  # Ensure this exists in AWS
  subnet_id              = data.aws_subnet.existing_public_subnet.id
  security_groups        = [data.aws_security_group.existing_sg.id]
  associate_public_ip_address = true

  iam_instance_profile   = data.aws_iam_instance_profile.existing_profile.name

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
    # git clone https://github.com/Behzad-Rajabalipour/Assignment2_K8s.git /home/ec2-user/app
    
    # Clone prod branch
    git clone --branch prod --single-branch https://github.com/CLO835-Final-Project-Hamza-Behzad/clo835_final_project.git /home/ec2-user/app

    # Change ownership
    sudo chown -R ec2-user:ec2-user /home/ec2-user/app
  EOF

  tags = {
    Name = "WorkerNode"
  }
}
