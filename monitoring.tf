# ---------- Module 4: Monitoring, alarms, billing ----------
resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email # confirm the subscription email after apply
}

locals {
  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${local.name}-ec2-cpu-high"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = aws_instance.web.id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "ec2_status" {
  alarm_name          = "${local.name}-ec2-status-check-failed" # uptime monitoring
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = aws_instance.web.id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name}-rds-cpu-high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each            = { api = aws_lambda_function.api.function_name, receipt = aws_lambda_function.receipt_processor.function_name }
  alarm_name          = "${local.name}-lambda-${each.key}-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = each.value }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name}-api-5xx"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  dimensions          = { ApiId = aws_apigatewayv2_api.http.id }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

# Billing alert via AWS Budgets (works in any region)
resource "aws_budgets_budget" "monthly" {
  name         = "${local.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name}-overview"
  dashboard_body = jsonencode({
    widgets = [
      { type = "metric", x = 0, y = 0, width = 12, height = 6, properties = { title = "EC2 CPU", region = var.aws_region, stat = "Average", period = 300, metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web.id]] } },
      { type = "metric", x = 12, y = 0, width = 12, height = 6, properties = { title = "RDS CPU & Connections", region = var.aws_region, period = 300, metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier], [".", "DatabaseConnections", ".", "."]] } },
      { type = "metric", x = 0, y = 6, width = 12, height = 6, properties = { title = "Lambda Invocations / Errors", region = var.aws_region, stat = "Sum", period = 300, metrics = [["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.api.function_name], [".", "Errors", ".", "."], ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.receipt_processor.function_name]] } },
      { type = "metric", x = 12, y = 6, width = 12, height = 6, properties = { title = "API Gateway Requests / 4xx / 5xx", region = var.aws_region, stat = "Sum", period = 300, metrics = [["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.http.id], [".", "4xx", ".", "."], [".", "5xx", ".", "."]] } },
      { type = "metric", x = 0, y = 12, width = 12, height = 6, properties = { title = "Kinesis Incoming Records", region = var.aws_region, stat = "Sum", period = 300, metrics = [["AWS/Kinesis", "IncomingRecords", "StreamName", aws_kinesis_stream.expenses.name]] } },
      { type = "log", x = 12, y = 12, width = 12, height = 6, properties = { title = "Recent API Lambda logs", region = var.aws_region, query = "SOURCE '${aws_cloudwatch_log_group.api.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20" } }
    ]
  })
}
