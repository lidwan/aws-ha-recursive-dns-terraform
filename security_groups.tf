resource "aws_security_group" "nlb_sg" {
  name        = "dns-nlb-sg"
  description = "Security group for DNS NLB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dns-nlb-sg"
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "dns-ec2-resolver-sg"
  description = "Security group for Unbound EC2 instances"
  vpc_id      = aws_vpc.main.id

  # Accept DNS traffic forwarded by NLB
  ingress {
    description     = "DNS UDP from NLB"
    from_port       = 53
    to_port         = 53
    protocol        = "udp"
    security_groups = [aws_security_group.nlb_sg.id]
  }

  ingress {
    description     = "DNS TCP from NLB (queries and health checks)"
    from_port       = 53
    to_port         = 53
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb_sg.id]
  }

  egress {
    description = "Recursive DNS queries outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Recursive DNS queries TCP outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # CloudWatch Agent API calls outbound
  egress {
    description = "CloudWatch Agent API over HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dns-ec2-resolver-sg"
  }
}
