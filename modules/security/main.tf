resource "aws_security_group" "sg" {
  name = "${var.cluster_name}-sg"
  description = "RKE2 cluster SG"
  vpc_id = var.vpc_id

  # intra-cluster all
  ingress { 
    from_port = 0 
    to_port = 0 
    protocol = "-1" 
    cidr_blocks = [var.vpc_cidr] 
  }

  # SSH
  ingress { 
    from_port = 22 
    to_port = 22 
    protocol = "tcp" 
    cidr_blocks = [var.ssh_ingress_cidr] 
  }

  # Kubernetes API (6443)
  dynamic "ingress" {
    for_each = var.open_k8s_api_to_world ? [1] : []
    content { 
      from_port = 6443 
      to_port = 6443 
      protocol = "tcp" 
      cidr_blocks = ["0.0.0.0/0"] 
    }
  }

  # RKE2 supervisor (9345) needed for agents to join
  ingress { 
    from_port = 9345 
    to_port = 9345 
    protocol = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Optional NodePorts could go here if desired
  egress { 
    from_port = 0 
    to_port = 0 
    protocol = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
  }

  tags = { Name = "${var.cluster_name}-sg" }
}
