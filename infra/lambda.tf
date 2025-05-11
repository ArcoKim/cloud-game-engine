data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "LoadTestLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "start"
  output_path = "start.zip"
}

resource "aws_lambda_function" "main" {
  filename      = data.archive_file.lambda.output_path
  function_name = "load-test-start"
  role          = aws_iam_role.lambda.arn
  handler       = "app.handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.13"

  logging_config {
    log_format = "Text"
  }

  environment {
    variables = {
      TASK_SUBNET         = data.aws_subnets.default.ids[0]
      TASK_SECURITY_GROUP = data.aws_security_group.default.id
      LOCUST_IMAGE        = var.LOCUST_IMAGE
      TASK_ROLE_ARN       = aws_iam_role.task_app.arn
      EXECUTION_ROLE_ARN  = aws_iam_role.task_execution.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda,
  ]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/load-test-start"
  retention_in_days = 14
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_app" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:Query",
      "ssm:GetParameter",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "iam:PassRole"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_app" {
  name   = "LoadTestStartPolicy"
  path   = "/"
  policy = data.aws_iam_policy_document.lambda_app.json
}

resource "aws_iam_role_policy_attachment" "lambda_app" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_app.arn
}