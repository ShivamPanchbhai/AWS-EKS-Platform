resource "aws_launch_template" "docker_lt" {
  name_prefix   = "docker-runtime-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = "ec2-ssm-role"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOF
  #!/bin/bash
  dnf update -y                 # user_data runs as root so no sudo
  dnf install -y docker
  systemctl enable docker
  systemctl start docker
  usermod -aG docker ssm-user   # Allow ssm-user to run Docker 
  dnf install -y git
  dnf install -y amazon-ssm-agent
  systemctl enable amazon-ssm-agent
  systemctl start amazon-ssm-agent
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "docker-runtime-asg"
    }
  }
}
