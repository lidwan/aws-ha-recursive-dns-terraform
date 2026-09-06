resource "aws_cloudwatch_dashboard" "dns_analytics" {
  dashboard_name = "DNS-Unbound-Analytics"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "log"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Top Queried Domains"
          region = data.aws_region.current.region
          query  = <<-QUERY
            SOURCE '/dns/unbound/query-logs'
            | fields @timestamp, @message
            | parse @message /info:\s+(?<client_ip>[^\s]+)\s+(?<domain>[^\s]+)\s+(?<query_type>[^\s]+)/
            | stats count(*) as query_count by domain
            | sort query_count desc
            | limit 15
          QUERY
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Top Querying Clients"
          region = data.aws_region.current.region
          query  = <<-QUERY
            SOURCE '/dns/unbound/query-logs'
            | fields @timestamp, @message
            | parse @message /info:\s+(?<client_ip>[^\s]+)\s+(?<domain>[^\s]+)\s+(?<query_type>[^\s]+)/
            | stats count(*) as query_count by client_ip
            | sort query_count desc
            | limit 15
          QUERY
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "DNS Query Volume Over Time"
          region = data.aws_region.current.region
          query  = <<-QUERY
            SOURCE '/dns/unbound/query-logs'
            | fields @timestamp, @message
            | filter @message like /info:/
            | stats count(*) as queries by bin(1m)
          QUERY
          view   = "timeSeries"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Query Types Distribution (A, AAAA, TXT, etc.)"
          region = data.aws_region.current.region
          query  = <<-QUERY
            SOURCE '/dns/unbound/query-logs'
            | fields @timestamp, @message
            | parse @message /info:\s+(?<client_ip>[^\s]+)\s+(?<domain>[^\s]+)\s+(?<query_type>[^\s]+)/
            | stats count(*) as total by query_type
            | sort total desc
          QUERY
          view   = "pie"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Top Queried TLDs"
          region = data.aws_region.current.region
          query  = <<-QUERY
            SOURCE '/dns/unbound/query-logs'
            | fields @timestamp, @message
            | parse @message /info:\s+(?<client_ip>[^\s]+)\s+(?<domain>[^\s]+)\s+(?<query_type>[^\s]+)/
            | parse domain /.*\.(?<tld>[^\.]+\.?)$/
            | stats count(*) as count by tld
            | sort count desc
            | limit 10
          QUERY
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Suspicious Long TXT Queries"
          region = data.aws_region.current.region
          query  = <<-QUERY
            SOURCE '/dns/unbound/query-logs'
            | fields @timestamp, @message
            | parse @message /info:\s+(?<client_ip>[^\s]+)\s+(?<domain>[^\s]+)\s+(?<query_type>[^\s]+)/
            | filter query_type = "TXT"
            | filter strlen(domain) > 40
            | stats count(*) as occurrences by client_ip, domain
            | sort occurrences desc
          QUERY
          view   = "table"
        }
      }
    ]
  })
}
