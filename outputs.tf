output "nlb_dns_name" { value = module.lb.nlb_dns_name }
output "controller_asg_name" { value = module.controllers.asg_name }
output "worker_asg_name" { value = module.workers.asg_name }
output "ssh_hint" { value = "Use your key '${var.key_name}' to SSH into any controller from the EC2 console public IPs" }

