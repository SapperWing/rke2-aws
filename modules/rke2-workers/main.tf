data "aws_ami" "al2023" {
  most_recent = true
  owners = ["137112412989"] # Amazon
  filter {
    name = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Reuse the controllers' token via data source from parent if desired; for simplicity, we generate here too.
# In production, pass it in instead. For this module, we assume controllers created token and workers just need URL+token.
# We'll accept token from parent via variable in a refinement; for now, make our own to keep module standalone.
# (Better: pass token from controllers; but Terraform doesn't easily read sibling module outputs if sensitive.)
resource "random_password" "cluster_token" { 
  length = 48 
  special = false 
}

locals {
  user_data = templatefile("${path.module}/templates/worker-userdata.sh", {
    rke2_version = var.rke2_version
    controller_nlb_dns= var.controller_nlb_dns
    cluster_token = random_password.cluster_token.result
  })
}

resource "aws_launch_template" "lt" {
  name_prefix = "${var.cluster_name}-wrk-"
  image_id = data.aws_ami.al2023.id
  key_name = var.key_name

  vpc_security_group_ids = [var.sg_id]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs { 
      volume_size = var.root_volume_size 
      volume_type = "gp3" 
      delete_on_termination = true 
    }
  }

  user_data = base64encode(local.user_data)
}

resource "aws_autoscaling_group" "asg" {
  name = "${var.cluster_name}-workers"
  min_size = var.min_size
  desired_capacity = var.desired
  max_size = var.max_size
  vpc_zone_identifier = var.subnet_ids
  health_check_type = "EC2"
  capacity_rebalance = var.capacity_rebalance

  # Always use MixedInstancesPolicy so we can run Spot diversified
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.lt.id
        version = "$Latest"
      }
      dynamic "override" {
        for_each = toset(var.instance_types)
        content { instance_type = override.value }
      }
    }
    instances_distribution {
      on_demand_percentage_above_base_capacity = var.spot ? 0 : 100
      spot_allocation_strategy = "capacity-optimized-prioritized"
      spot_max_price = var.spot && var.spot_max_price != "" ? var.spot_max_price : null
    }
  }

  tag { 
    key = "Name"
    value = "${var.cluster_name}-worker" 
    propagate_at_launch = true 
  }
  tag { 
    key = "kubernetes.io/cluster/${var.cluster_name}" 
    value = "owned"
    propagate_at_launch = true 
  }
}

output "asg_name" { value = aws_autoscaling_group.asg.name }

