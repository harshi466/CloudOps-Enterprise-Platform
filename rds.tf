# ---------- Module 2: Managed database, private, encrypted ----------
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.private_db[*].id
}

resource "aws_db_parameter_group" "pg" {
  name   = "${local.name}-pg15"
  family = "postgres15"
  parameter {
    name  = "rds.force_ssl" # encryption in transit
    value = "1"
  }
}

resource "aws_db_instance" "main" {
  identifier              = "${local.name}-db"
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = "gp3"
  storage_encrypted       = true # encryption at rest
  db_name                 = "expenses"
  username                = "app"
  password                = random_password.db.result
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  parameter_group_name    = aws_db_parameter_group.pg.name
  publicly_accessible     = false
  backup_retention_period = 7
  skip_final_snapshot     = true # lab setting; use final snapshot in production
  deletion_protection     = false
  multi_az                = false
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name}/db-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "app"
    password = random_password.db.result
    host     = aws_db_instance.main.address
    dbname   = "expenses"
    url      = "postgresql://app:${random_password.db.result}@${aws_db_instance.main.address}:5432/expenses?sslmode=require"
  })
}

# DynamoDB (NoSQL) for receipt metadata
resource "aws_dynamodb_table" "receipts" {
  name         = "${local.name}-receipts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "receipt_key"
  attribute {
    name = "receipt_key"
    type = "S"
  }
  server_side_encryption { enabled = true }
  point_in_time_recovery { enabled = true }
}
