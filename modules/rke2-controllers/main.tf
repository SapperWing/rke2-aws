# AMI AWS Linux 2023
data "aws_ami" "al2023" {
  most_recent = true
  owners = ["137112412989"] # Amazon
  filter {
    name = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "random_password" "cluster_token" { 
  length = 48 
  special = false 
}

locals {
  user_data = templatefile("${path.module}/templates/controller-userdata.sh", {
    cluster_token = random_password.cluster_token.result
    rke2_version = var.rke2_version
    disable_ingress_nginx = var.disable_ingress_nginx
    lb_dns_name = var.lb_dns_name
  })
}

resource "aws_launch_template" "lt" {
  name_prefix = "${var.cluster_name}-ctrl-"
  image_id = data.aws_ami.al2023.id
  key_name = var.key_name
  instance_type = var.spot ? null : var.instance_types[0]
  update_default_version = true

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

  # If you want Spot controllers (not recommended), enable here:
  dynamic "instance_market_options" {
    for_each = var.spot ? [1] : []
    content {
      market_type = "spot"
      spot_options { instance_interruption_behavior = "terminate" }
    }
  }
}

# If spot=false (recommended), use simple ASG with Launch Template and a single instance type
# If spot=true, use MixedInstancesPolicy so controllers can run on multiple types
resource "aws_autoscaling_group" "asg" {
  name = "${var.cluster_name}-controllers"
  min_size = var.controller_count
  desired_capacity = var.controller_count
  max_size = var.controller_count
  vpc_zone_identifier = var.subnet_ids
  health_check_type = "EC2"
  health_check_grace_period = 180
  capacity_rebalance = var.capacity_rebalance

  dynamic "mixed_instances_policy" {
    for_each = var.spot ? [1] : []
    content {
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
        on_demand_percentage_above_base_capacity = 0 # all Spot if spot=true
        spot_allocation_strategy = "lowest-price"
      }
    }
  }

  dynamic "launch_template" {
    for_each = var.spot ? [] : [1]
    content {
      id = aws_launch_template.lt.id
      version = "$Latest"
    }
  }

  target_group_arns = [var.nlb_tg_6443_arn, var.nlb_tg_9345_arn]

  tag { 
    key = "Name"
    value = "${var.cluster_name}-controller"
    propagate_at_launch = true 
  }
  tag { 
    key = "kubernetes.io/cluster/${var.cluster_name}"
    value = "owned" 
    propagate_at_launch = true 
  }
}

output "asg_name" { value = aws_autoscaling_group.asg.name }
output "cluster_token" { 
  value = random_password.cluster_token.result 
  sensitive = true 
}

