resource "aws_ecs_cluster" "main" {
  name = "load-test"
}

data "aws_iam_policy_document" "assume_ecs_tasks" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "ecsTaskExecutionRole-load-test"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "task_logs" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "task_app" {
  name               = "LoadTestAppRole"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}

data "aws_iam_policy_document" "task_app" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ssm:GetParameter",
      "s3:PutObject",
      "s3:ListBucket"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "task_app" {
  name   = "LoadTestAppPolicy"
  path   = "/"
  policy = data.aws_iam_policy_document.task_app.json
}

resource "aws_iam_role_policy_attachment" "task_app" {
  role       = aws_iam_role.task_app.name
  policy_arn = aws_iam_policy.task_app.arn
}