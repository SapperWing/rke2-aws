variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "ssh_ingress_cidr" { type = string }
variable "open_k8s_api_to_world"{ type = bool }
