data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "resolver_lt" {
  name_prefix   = "dns-unbound-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.resolver_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -xe

              # 1. Install Unbound and CloudWatch Agent
              dnf update -y
              dnf install -y unbound amazon-cloudwatch-agent

              # 2. Configure Unbound
              mkdir -p /etc/unbound/conf.d/
              mkdir -p /var/log/unbound/ /var/lib/unbound/
              chown -R unbound:unbound /var/log/unbound/ /var/lib/unbound/

              cat <<'CONFIG' > /etc/unbound/unbound.conf
              server:
                  # The package default chroot would make /var/log/... resolve
                  # below /etc/unbound. Keep the absolute log path usable.
                  chroot: ""
                  directory: "/var/lib/unbound"
                  username: "unbound"

                  port: 53
                  interface: 0.0.0.0
                  do-ip4: yes
                  do-ip6: no

                  access-control: 127.0.0.0/8 allow
                  access-control: 10.0.0.0/16 allow
                  access-control: 0.0.0.0/0 allow

                  hide-identity: yes
                  hide-version: yes
                  harden-glue: yes
                  harden-dnssec-stripped: yes
                  use-caps-for-id: yes

                  prefetch: yes
                  cache-min-ttl: 60
                  cache-max-ttl: 86400
                  msg-cache-size: 64m
                  rrset-cache-size: 128m

                  unwanted-reply-threshold: 10000

                  verbosity: 1
                  log-queries: yes
                  log-replies: no
                  log-servfail: yes
                  log-time-ascii: yes
                  use-syslog: no
                  logfile: "/var/log/unbound/unbound.log"
              CONFIG

              # 3. Configure CloudWatch Agent
              cat <<'CW_CONFIG' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              {
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/unbound/unbound.log",
                          "log_group_name": "/dns/unbound/query-logs",
                          "log_stream_name": "{instance_id}",
                          "timestamp_format": "%b %d %H:%M:%S"
                        }
                      ]
                    }
                  }
                }
              }
              CW_CONFIG

              # 4. Start services
              unbound-checkconf /etc/unbound/unbound.conf
              systemctl enable unbound
              if ! systemctl restart unbound; then
                systemctl --no-pager --full status unbound || true
                journalctl --no-pager -u unbound -n 50 || true
                exit 1
              fi
              systemctl is-active --quiet unbound

              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config \
                -m ec2 \
                -s \
                -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "unbound-dns-resolver"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
