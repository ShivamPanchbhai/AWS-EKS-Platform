# Fetch default security group of the VPC
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = data.aws_subnet.selected.vpc_id
}

# Fetch subnet to get VPC ID
data "aws_subnet" "selected" {
  id = "subnet-076bfaf1ee40ec8fd"
}

resource "aws_launch_template" "docker_lt" {
  name_prefix   = "docker-runtime-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = "ec2-ssm-role"
  }

  vpc_security_group_ids = [
    data.aws_security_group.default.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    dnf install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    usermod -aG docker ec2-user
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "docker-runtime-asg"
    }
  }
}
