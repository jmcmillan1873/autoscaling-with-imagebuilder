# Define the Launch template that will configure the instances that will perform the prowler scans
resource "aws_launch_template" "custom_lt" {
  name_prefix            = "custom-lt-"
  image_id               = aws_ssm_parameter.custom_built_custom_id.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.MyExampleSG.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.scanbox.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "AnExampleInstance"
      Project = var.project
    }
  }
}

# Create the Auto Scaling Group that will spawn the instances from the Launch Template
resource "aws_autoscaling_group" "custom_asg" {
  name                      = "custom-asg"
  desired_capacity          = 0
  max_size                  = 1
  min_size                  = 0
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.custom_lt.id
    version = "$Latest"

  }

  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
}
