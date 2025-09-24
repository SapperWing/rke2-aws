variable "region" { 
  type = string
  default = "us-east-1" 
}
variable "cluster_name" { 
  type = string
  default = "rke2-demo" 
}
variable "key_name" { type = string } # existing EC2 key pair

# Sizes / counts
variable "controller_count" { 
  type = number
  default = 3 
}
variable "worker_desired" { 
  type = number 
  default = 3 
}
variable "worker_min" { 
  type = number
  default = 1 
}
variable "worker_max" { 
  type = number 
  default = 10 
}

variable "controller_instance_types" {
  # Order matters: first is your preferred On-Demand type; if controllers_spot=true we’ll let ASG use overrides.
  type = list(string)
  default = ["t3.small"]
}

variable "worker_instance_types" {
  # Multiple types recommended for Spot diversity
  type = list(string)
  default = ["t3.micro", "t3.small", "t3a.small"]
}

variable "controller_root_volume_size" { 
  type = number
  default = 40 
}
variable "worker_root_volume_size" { 
  type = number
  default = 30 
}

# Spot knobs
variable "controllers_spot" { 
  type = bool
  default = false 
}
variable "workers_spot" { 
  type = bool
  default = true 
}
variable "worker_spot_max_price" { 
  type = string
  default = "" 
} # "" = market price
variable "enable_capacity_rebalance" { 
  type = bool
  default = true 
} # ASG replaces Spot when interrupted

# Exposure / networking
variable "open_k8s_api_to_world" { 
  type = bool
  default = true 
}
variable "ssh_ingress_cidr" { 
  type = string 
  default = "0.0.0.0/0" 
}

# RKE2 / platform
variable "rke2_version" { 
  type = string
  default = "" 
} # e.g., "v1.28.10+rke2r1"
variable "disable_ingress_nginx" { 
  type = bool
  default = true 
} # Big Bang usually brings Istio
variable "vpc_cidr" { 
  type = string 
  default = "10.61.0.0/16" 
}
