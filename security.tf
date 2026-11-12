# ---------- Security groups ----------
resource "aws_security_group" "web" {
  name        = "${local.name}-web-sg"
  description = "Public web server: HTTP/HTTPS only (no SSH - use SSM Session Manager)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "PostgreSQL reachable only from app subnets and web tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from web SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
  ingress {
    description = "Postgres from private app subnets (Kubernetes nodes)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = aws_subnet.private_app[*].cidr_block
  }
}
