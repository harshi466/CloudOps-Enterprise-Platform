output "web_server_public_ip" { value = aws_instance.web.public_ip }
output "web_server_url" { value = "http://${aws_instance.web.public_ip}" }
output "serverless_api_url" { value = aws_apigatewayv2_stage.default.invoke_url }
output "predict_url" { value = "${aws_apigatewayv2_stage.default.invoke_url}/predict" }
output "receipts_bucket" { value = aws_s3_bucket.receipts.id }
output "datalake_bucket" { value = aws_s3_bucket.datalake.id }
output "kinesis_stream" { value = aws_kinesis_stream.expenses.name }
output "rds_endpoint" { value = aws_db_instance.main.address }
output "db_secret_name" { value = aws_secretsmanager_secret.db.name }
output "ecr_repositories" { value = { for k, r in aws_ecr_repository.svc : k => r.repository_url } }
output "dashboard_url" { value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}" }
output "athena_workgroup" { value = aws_athena_workgroup.wg.name }
output "github_ci_role_arn" { value = try(aws_iam_role.github_ci[0].arn, null) }
output "eks_cluster_name" { value = try(aws_eks_cluster.main[0].name, null) }
