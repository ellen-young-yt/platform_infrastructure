# CloudWatch Log Group for Airflow containers
resource "aws_cloudwatch_log_group" "airflow" {
  name              = "/ecs/${var.project_name}-${var.environment}-airflow"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-airflow-logs"
  })
}

resource "aws_ecs_cluster" "airflow" {
  name = "${var.project_name}-${var.environment}-airflow"

  setting {
    name  = "containerInsights"
    value = var.environment == "prod" ? "enabled" : "disabled" #checkov:skip=CKV_AWS_65:Cost optimization - insights disabled for non-prod
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

locals {
  log_group_name = "/ecs/${var.project_name}-${var.environment}-airflow"
}

resource "aws_ecs_task_definition" "airflow_webserver" {
  family                   = "${var.project_name}-${var.environment}-airflow-webserver"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.webserver_cpu
  memory                   = var.webserver_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

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
          value = "LocalExecutor"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
          value = var.database_connection_string
        }
      ]

      secrets = [
        {
          name      = "AIRFLOW__WEBSERVER__SECRET_KEY"
          valueFrom = var.airflow_webserver_secret_key_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
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
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name    = "airflow-scheduler"
      image   = var.airflow_image
      command = ["scheduler"]

      environment = [
        {
          name  = "AIRFLOW__CORE__EXECUTOR"
          value = "LocalExecutor"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
          value = var.database_connection_string
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
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
    security_groups  = [var.ecs_security_group_id]
    subnets          = var.public_subnet_ids
    assign_public_ip = true
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
    security_groups  = [var.ecs_security_group_id]
    subnets          = var.public_subnet_ids
    assign_public_ip = true
  }

  tags = var.tags
}

data "aws_region" "current" {}
