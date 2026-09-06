resource "aws_cloudwatch_log_group" "dns_query_logs" {
  name              = "/dns/unbound/query-logs"
  retention_in_days = 14

  tags = {
    Application = "Unbound-DNS"
  }
}
