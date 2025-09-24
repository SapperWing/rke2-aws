variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "sg_id" { type = string }
variable "key_name" { type = string }
variable "controller_count" { type = number }
variable "instance_types" { type = list(string) }
variable "root_volume_size" { type = number }
variable "rke2_version" { type = string }
variable "disable_ingress_nginx" { type = bool }

variable "spot" { type = bool }
variable "capacity_rebalance" { type = bool }

variable "lb_dns_name" { type = string } # For TLS SAN + kubeconfig server
variable "nlb_tg_6443_arn" { type = string }
variable "nlb_tg_9345_arn" { type = string }
