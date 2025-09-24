variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "sg_id" { type = string }
variable "key_name" { type = string }

variable "controller_nlb_dns" { type = string }

variable "desired" { type = number }
variable "min_size" { type = number }
variable "max_size" { type = number }

variable "instance_types" { type = list(string) }
variable "root_volume_size" { type = number }
variable "rke2_version" { type = string }

variable "spot" { type = bool }
variable "spot_max_price" { type = string }
variable "capacity_rebalance" { type = bool }
