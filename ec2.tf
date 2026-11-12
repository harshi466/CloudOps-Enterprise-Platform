# ---------- Module 1: Virtual machine + web server ----------
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "ec2" {
  name = "${local.name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  monitoring             = true

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }
  root_block_device {
    encrypted   = true
    volume_size = 12
    volume_type = "gp3"
  }

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y nginx docker amazon-cloudwatch-agent
    systemctl enable --now nginx docker
    cat > /usr/share/nginx/html/index.html <<'HTML'
    <html><body style="font-family:sans-serif;text-align:center;margin-top:12vh">
    <h1>CloudOps IaaS Web Server</h1><p>Provisioned with Terraform on EC2 (${local.name})</p>
    <p>Virtual Machine layer - Module 1</p></body></html>
    HTML
  EOT

  tags = { Name = "${local.name}-web" }
}
