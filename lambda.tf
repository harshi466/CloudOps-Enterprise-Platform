# ---------- Module 3: Serverless ----------
data "archive_file" "receipt" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/receipt_processor"
  output_path = "${path.module}/.build/receipt.zip"
}

data "archive_file" "api" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/api_handler"
  output_path = "${path.module}/.build/api.zip"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- Least-privilege roles (one per function) ---
resource "aws_iam_role" "receipt" {
  name               = "${local.name}-receipt-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy" "receipt" {
  role = aws_iam_role.receipt.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.receipts.arn },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.receipt.arn}:*" }
    ]
  })
}

resource "aws_iam_role" "api" {
  name               = "${local.name}-api-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy" "api" {
  role = aws_iam_role.api.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.datalake.arn}/models/*" },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.api.arn}:*" }
    ]
  })
}

resource "aws_cloudwatch_log_group" "receipt" {
  name              = "/aws/lambda/${local.name}-receipt-processor"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${local.name}-api"
  retention_in_days = 14
}

resource "aws_lambda_function" "receipt_processor" {
  function_name    = "${local.name}-receipt-processor"
  role             = aws_iam_role.receipt.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.receipt.output_path
  source_code_hash = data.archive_file.receipt.output_base64sha256
  timeout          = 15
  environment { variables = { RECEIPTS_TABLE = aws_dynamodb_table.receipts.name } }
  depends_on = [aws_cloudwatch_log_group.receipt]
}

resource "aws_lambda_function" "api" {
  function_name    = "${local.name}-api"
  role             = aws_iam_role.api.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256
  timeout          = 10
  environment {
    variables = { MODEL_BUCKET = aws_s3_bucket.datalake.id, MODEL_KEY = "models/model.json" }
  }
  depends_on = [aws_cloudwatch_log_group.api]
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.receipt_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.receipts.arn
}

# --- API Gateway (HTTP API) -> Lambda ---
resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "routes" {
  for_each  = toset(["GET /health", "POST /predict"])
  api_id    = aws_apigatewayv2_api.http.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 25
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
