output "nlb_dns_name" {
  description = "The public DNS endpoint of the Network Load Balancer"
  value       = aws_lb.dns.dns_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group receiving Unbound query logs"
  value       = aws_cloudwatch_log_group.dns_query_logs.name
}

output "dashboard_name" {
  description = "Name of the provisioned CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.dns_analytics.dashboard_name
}
