terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
    random = { source = "hashicorp/random", version = ">= 3.5" }
    template = { source = "hashicorp/template", version = ">= 2.2" }
  }
}

provider "aws" { region = var.region }

locals {
  rke2_key_name = (
    var.key_name != "" ? var.key_name : "rke2-key"
  )
}

resource "aws_key_pair" "rke2" {
  key_name   = local.rke2_key_name
  public_key = file(var.public_key_path)  # e.g., ~/.ssh/id_rsa.pub
}

# 1) Network
module "network" {
  source = "./modules/network"
  cluster_name = var.cluster_name
  vpc_cidr = var.vpc_cidr
}

# 2) Security (SG rules)
module "security" {
  source = "./modules/security"
  vpc_id = module.network.vpc_id
  vpc_cidr = var.vpc_cidr
  cluster_name = var.cluster_name
  ssh_ingress_cidr = var.ssh_ingress_cidr
  open_k8s_api_to_world = var.open_k8s_api_to_world
}

# 3) Load balancer (NLB) for 6443 and 9345 over controllers
module "lb" {
  source = "./modules/loadbalancer"
  cluster_name = var.cluster_name
  vpc_id = module.network.vpc_id
  subnet_ids = module.network.public_subnet_ids
  # Target groups will attach to controllers ASG later
}

# 4) Controllers (ASG + Launch Template)
module "controllers" {
  source = "./modules/rke2-controllers"
  cluster_name = var.cluster_name
  vpc_id = module.network.vpc_id
  subnet_ids = module.network.public_subnet_ids
  sg_id = module.security.sg_id
  key_name = aws_key_pair.rke2.key_name

  controller_count = var.controller_count
  instance_types = var.controller_instance_types
  root_volume_size = var.controller_root_volume_size
  rke2_version = var.rke2_version
  disable_ingress_nginx = var.disable_ingress_nginx

  spot = var.controllers_spot
  capacity_rebalance = var.enable_capacity_rebalance

  # Pass LB DNS for SAN and kubeconfig rewrite
  lb_dns_name = module.lb.nlb_dns_name

  # Attach NLB target groups so clients can hit any controller
  nlb_tg_6443_arn = module.lb.tg_6443_arn
  nlb_tg_9345_arn = module.lb.tg_9345_arn
}

# 5) Workers (ASG + Launch Template) — Spot by default
module "workers" {
  source = "./modules/rke2-workers"
  cluster_name = var.cluster_name
  vpc_id = module.network.vpc_id
  subnet_ids = module.network.public_subnet_ids
  sg_id = module.security.sg_id
  key_name      = aws_key_pair.rke2.key_name

  # connect to controllers via NLB supervisor on 9345
  controller_nlb_dns = module.lb.nlb_dns_name

  desired = var.worker_desired
  min_size = var.worker_min
  max_size = var.worker_max

  instance_types = var.worker_instance_types
  root_volume_size = var.worker_root_volume_size
  rke2_version = var.rke2_version

  spot = var.workers_spot
  spot_max_price = var.worker_spot_max_price
  capacity_rebalance = var.enable_capacity_rebalance
}

