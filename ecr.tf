resource "aws_ecr_repository" "svc" {
  for_each             = toset(["user-service", "expense-service", "frontend"])
  name                 = "${local.name}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_ecr_lifecycle_policy" "svc" {
  for_each   = aws_ecr_repository.svc
  repository = each.value.name
  policy = jsonencode({
    rules = [{ rulePriority = 1, description = "keep last 10", selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }, action = { type = "expire" } }]
  })
}
