resource "aws_lb_target_group" "dns" {
  name        = "unbound-dns-tg"
  port        = 53
  protocol    = "TCP_UDP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "53"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 5
  }

  tags = {
    Name = "unbound-dns-tg"
  }
}

resource "aws_lb" "dns" {
  name               = "unbound-dns-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.nlb_sg.id]

  tags = {
    Name = "unbound-dns-nlb"
  }
}

resource "aws_lb_listener" "dns" {
  load_balancer_arn = aws_lb.dns.arn
  port              = 53
  protocol          = "TCP_UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dns.arn
  }
}

resource "aws_autoscaling_group" "dns_asg" {
  name_prefix         = "dns-asg-"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.dns.arn]

  min_size         = 3
  max_size         = 6
  desired_capacity = 3

  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.resolver_lt.id
    version = aws_launch_template.resolver_lt.latest_version
  }

  # Zero-downtime rolling update strategy
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      instance_warmup        = 180
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "unbound-asg-worker"
    propagate_at_launch = true
  }

  depends_on = [aws_cloudwatch_log_group.dns_query_logs]

  lifecycle {
    create_before_destroy = true
  }
}
