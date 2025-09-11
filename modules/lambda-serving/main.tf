
resource "aws_api_gateway_rest_api" "ml_api" {
  name        = "${var.project_name}-${var.environment}-ml-api"
  description = "API Gateway for ML model serving"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

resource "aws_api_gateway_resource" "models" {
  rest_api_id = aws_api_gateway_rest_api.ml_api.id
  parent_id   = aws_api_gateway_rest_api.ml_api.root_resource_id
  path_part   = "models"
}

resource "aws_api_gateway_resource" "model_predict" {
  rest_api_id = aws_api_gateway_rest_api.ml_api.id
  parent_id   = aws_api_gateway_resource.models.id
  path_part   = "{model_name}"
}

resource "aws_api_gateway_resource" "predict" {
  rest_api_id = aws_api_gateway_rest_api.ml_api.id
  parent_id   = aws_api_gateway_resource.model_predict.id
  path_part   = "predict"
}

resource "aws_api_gateway_method" "predict_post" {
  rest_api_id      = aws_api_gateway_rest_api.ml_api.id
  resource_id      = aws_api_gateway_resource.predict.id
  http_method      = "POST"
  authorization    = "AWS_IAM"
  api_key_required = var.enable_api_key
}

resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-${var.environment}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count      = length(var.private_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "${var.project_name}-${var.environment}-lambda-s3-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "arn:aws:kms:*:*:key/*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "s3.*.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/${var.environment}/*"
      }
    ]
  })
}

resource "aws_lambda_function" "model_predictor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-model-predictor"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  dynamic "vpc_config" {
    for_each = length(var.private_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.private_subnet_ids
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  environment {
    variables = {
      ENVIRONMENT  = var.environment
      PROJECT_NAME = var.project_name
    }
  }

  tags = var.tags
}

resource "aws_security_group" "lambda" {
  count                  = length(var.private_subnet_ids) > 0 ? 1 : 0
  name_prefix            = "${var.project_name}-${var.environment}-lambda-"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.root}/lambda_function.zip"

  source {
    content = templatefile("${path.module}/templates/lambda_function.py", {
      project_name = var.project_name
      environment  = var.environment
    })
    filename = "lambda_function.py"
  }
}

resource "aws_api_gateway_integration" "predict_post" {
  rest_api_id             = aws_api_gateway_rest_api.ml_api.id
  resource_id             = aws_api_gateway_resource.predict.id
  http_method             = aws_api_gateway_method.predict_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.model_predictor.invoke_arn
}

module "cors_predict" {
  source          = "./cors"
  rest_api_id     = aws_api_gateway_rest_api.ml_api.id
  resource_id     = aws_api_gateway_resource.predict.id
  allowed_methods = ["POST", "OPTIONS"]
}

resource "aws_api_gateway_method_response" "predict_post_200" {
  rest_api_id = aws_api_gateway_rest_api.ml_api.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_post.http_method
  status_code = "200"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.model_predictor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.ml_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "ml_api" {
  depends_on = [
    aws_api_gateway_integration.predict_post,
    module.cors_predict, # ensures OPTIONS is created
  ]

  rest_api_id = aws_api_gateway_rest_api.ml_api.id
}

resource "aws_api_gateway_stage" "ml_api" {
  deployment_id = aws_api_gateway_deployment.ml_api.id
  rest_api_id   = aws_api_gateway_rest_api.ml_api.id
  stage_name    = var.environment

  tags = var.tags
}

resource "aws_api_gateway_api_key" "ml_api" {
  count = var.enable_api_key ? 1 : 0
  name  = "${var.project_name}-${var.environment}-ml-api-key"

  tags = var.tags
}

resource "aws_api_gateway_usage_plan" "ml_api" {
  count = var.enable_api_key ? 1 : 0
  name  = "${var.project_name}-${var.environment}-ml-api-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.ml_api.id
    stage  = aws_api_gateway_stage.ml_api.stage_name
  }

  quota_settings {
    limit  = var.api_quota_limit
    period = "MONTH"
  }

  throttle_settings {
    rate_limit  = var.api_rate_limit
    burst_limit = var.api_burst_limit
  }

  tags = var.tags
}

resource "aws_api_gateway_usage_plan_key" "ml_api" {
  count         = var.enable_api_key ? 1 : 0
  key_id        = aws_api_gateway_api_key.ml_api[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.ml_api[0].id
}
