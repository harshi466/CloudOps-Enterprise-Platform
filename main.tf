data "aws_availability_zones" "available" { state = "available" }
data "aws_caller_identity" "me" {}

locals {
  name = "${var.project}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}
