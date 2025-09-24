output "nlb_dns_name" { value = aws_lb.nlb.dns_name }
output "tg_6443_arn" { value = aws_lb_target_group.tg_6443.arn }
output "tg_9345_arn" { value = aws_lb_target_group.tg_9345.arn }
