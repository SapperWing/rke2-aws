resource "aws_lb" "nlb" {
  name = "${var.cluster_name}-nlb"
  internal = false
  load_balancer_type = "network"
  subnets = var.subnet_ids
  enable_cross_zone_load_balancing = true
}

# Target groups for TCP 6443 (kube-apiserver) and 9345 (rke2 supervisor)
resource "aws_lb_target_group" "tg_6443" {
  name = "${var.cluster_name}-tg-6443"
  port = 6443
  protocol = "TCP"
  vpc_id = var.vpc_id
  target_type = "instance"
  health_check {
    protocol = "TCP"
    port = "6443"
  }
}

resource "aws_lb_target_group" "tg_9345" {
  name = "${var.cluster_name}-tg-9345"
  port = 9345
  protocol = "TCP"
  vpc_id = var.vpc_id
  target_type = "instance"
  health_check {
    protocol = "TCP"
    port = "9345"
  }
}

resource "aws_lb_listener" "l_6443" {
  load_balancer_arn = aws_lb.nlb.arn
  port = 6443
  protocol = "TCP"
  default_action { 
    type = "forward" 
    target_group_arn = aws_lb_target_group.tg_6443.arn 
  }
}

resource "aws_lb_listener" "l_9345" {
  load_balancer_arn = aws_lb.nlb.arn
  port = 9345
  protocol = "TCP"
  default_action { 
    type = "forward" 
    target_group_arn = aws_lb_target_group.tg_9345.arn 
  }
}

