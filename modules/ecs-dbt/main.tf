# ECS Cluster
resource "aws_ecs_cluster" "dbt" {
  name = "${var.project_name}-${var.environment}-dbt"

  setting {
    name  = "containerInsights"
    value = var.environment == "prod" ? "enabled" : "disabled" #checkov:skip=CKV_AWS_65:Cost optimization - insights disabled for non-prod
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-dbt-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "dbt" {
  cluster_name = aws_ecs_cluster.dbt.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Group managed by monitoring module
locals {
  log_group_name = "/ecs/${var.project_name}-${var.environment}-${var.service_name}"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "dbt" {
  family                   = "${var.service_name}-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = var.container_name
      image = var.image_uri

      essential = true


      environment = [
        for key, value in var.environment_variables : {
          name  = key
          value = value
        }
      ]

      secrets = [
        {
          name      = "SNOWFLAKE_CREDENTIALS"
          valueFrom = var.database_secret_name
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

    }
  ])

  tags = var.tags
}

# Data sources
data "aws_region" "current" {}
