data "aws_iam_policy_document" "assume_ec2" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eb" {
  name               = "aws-elasticbeanstalk-ec2-role-cge"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_instance_profile" "eb" {
  name = "aws-elasticbeanstalk-ec2-role-cge"
  role = aws_iam_role.eb.name
}

resource "aws_iam_role_policy_attachment" "eb" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier",
  ])

  role       = aws_iam_role.eb.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "eb_app" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:PutItem",
      "dynamodb:Query",
      "ssm:PutParameter"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "eb_app" {
  name   = "ElasticBeanstalkAppPolicy"
  path   = "/"
  policy = data.aws_iam_policy_document.eb_app.json
}

resource "aws_iam_role_policy_attachment" "eb_app" {
  role       = aws_iam_role.eb.name
  policy_arn = aws_iam_policy.eb_app.arn
}

resource "aws_elastic_beanstalk_application" "main" {
  name = "cloud-game-engine"
}

resource "aws_s3_bucket" "main" {
  bucket_prefix = "cloud-game-engine-eb-"
  force_destroy = true
}

data "archive_file" "web" {
  type        = "zip"
  source_dir  = "../web"
  output_path = "flask.zip"
  excludes = [
    ".venv",
    "routes/__pycache__"
  ]
}

resource "aws_s3_object" "main" {
  bucket = aws_s3_bucket.main.id
  key    = "flask.zip"
  source = data.archive_file.web.output_path
  etag   = filemd5(data.archive_file.web.output_path)
}

resource "aws_elastic_beanstalk_application_version" "main" {
  name        = "main"
  application = aws_elastic_beanstalk_application.main.name
  bucket      = aws_s3_bucket.main.id
  key         = aws_s3_object.main.id
}

resource "aws_elastic_beanstalk_environment" "main" {
  name                = "production"
  application         = aws_elastic_beanstalk_application.main.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.7.0 running Python 3.13"
  version_label       = aws_elastic_beanstalk_application_version.main.name

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "/health"
  }
}