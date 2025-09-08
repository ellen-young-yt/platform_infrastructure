resource "aws_ecs_cluster" "airflow" {
  name = "${var.project_name}-${var.environment}-airflow"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-airflow-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "airflow" {
  cluster_name = aws_ecs_cluster.airflow.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_iam_role" "airflow_execution" {
  name = "${var.project_name}-${var.environment}-airflow-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "airflow_execution" {
  role       = aws_iam_role.airflow_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "airflow_task" {
  name = "${var.project_name}-${var.environment}-airflow-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "airflow_task" {
  name = "${var.project_name}-${var.environment}-airflow-task-policy"
  role = aws_iam_role.airflow_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
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

resource "aws_cloudwatch_log_group" "airflow" {
  name              = "/ecs/${var.project_name}-${var.environment}-airflow"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_ecs_task_definition" "airflow_webserver" {
  family                   = "${var.project_name}-${var.environment}-airflow-webserver"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.webserver_cpu
  memory                   = var.webserver_memory
  execution_role_arn       = aws_iam_role.airflow_execution.arn
  task_role_arn            = aws_iam_role.airflow_task.arn

  container_definitions = jsonencode([
    {
      name    = "airflow-webserver"
      image   = var.airflow_image
      command = ["webserver"]

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "AIRFLOW__CORE__EXECUTOR"
          value = "CeleryExecutor"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
          value = var.database_connection_string
        },
        {
          name  = "AIRFLOW__CELERY__BROKER_URL"
          value = var.redis_connection_string
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.airflow.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "webserver"
        }
      }

      essential = true
    }
  ])

  tags = var.tags
}

resource "aws_ecs_task_definition" "airflow_scheduler" {
  family                   = "${var.project_name}-${var.environment}-airflow-scheduler"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.scheduler_cpu
  memory                   = var.scheduler_memory
  execution_role_arn       = aws_iam_role.airflow_execution.arn
  task_role_arn            = aws_iam_role.airflow_task.arn

  container_definitions = jsonencode([
    {
      name    = "airflow-scheduler"
      image   = var.airflow_image
      command = ["scheduler"]

      environment = [
        {
          name  = "AIRFLOW__CORE__EXECUTOR"
          value = "CeleryExecutor"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
          value = var.database_connection_string
        },
        {
          name  = "AIRFLOW__CELERY__BROKER_URL"
          value = var.redis_connection_string
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.airflow.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "scheduler"
        }
      }

      essential = true
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "airflow_webserver" {
  name            = "${var.project_name}-${var.environment}-airflow-webserver"
  cluster         = aws_ecs_cluster.airflow.id
  task_definition = aws_ecs_task_definition.airflow_webserver.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [var.ecs_security_group_id]
    subnets         = var.private_subnet_ids
  }

  tags = var.tags
}

resource "aws_ecs_service" "airflow_scheduler" {
  name            = "${var.project_name}-${var.environment}-airflow-scheduler"
  cluster         = aws_ecs_cluster.airflow.id
  task_definition = aws_ecs_task_definition.airflow_scheduler.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [var.ecs_security_group_id]
    subnets         = var.private_subnet_ids
  }

  tags = var.tags
}

data "aws_region" "current" {}