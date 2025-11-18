resource "aws_ecs_cluster" "superset" {
  name = "${var.project_name}-${var.environment}-superset"

  setting {
    name  = "containerInsights"
    value = var.environment == "prod" ? "enabled" : "disabled" #checkov:skip=CKV_AWS_65:Cost optimization - insights disabled for non-prod
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-superset-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "superset" {
  cluster_name = aws_ecs_cluster.superset.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# IAM roles are now managed centrally - see main.tf iam_superset module

# CloudWatch Log Group managed by monitoring module
locals {
  log_group_name = "/ecs/${var.project_name}-${var.environment}-superset"
}

# Superset initialization task definition (run once to set up database)
resource "aws_ecs_task_definition" "superset_init" {
  family                   = "${var.project_name}-${var.environment}-superset-init"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "superset-init"
      image = var.superset_image

      command = [
        "/bin/sh",
        "-c",
        <<-EOT
          set -e
          echo "Running database upgrade..."
          superset db upgrade
          echo "Initializing Superset..."
          superset init
          echo "Creating admin user..."
          superset fab create-admin \
            --username admin \
            --firstname Admin \
            --lastname User \
            --email admin@example.com \
            --password admin
          echo "Superset initialization completed successfully!"
        EOT
      ]

      environment = var.redis_host != "" ? [
        {
          name  = "REDIS_HOST"
          value = var.redis_host
        },
        {
          name  = "REDIS_PORT"
          value = tostring(var.redis_port)
        },
        {
          name  = "REDIS_SSL"
          value = "false"
        }
      ] : []

      secrets = concat(
        var.rds_secret_arn != "" ? [
          {
            name      = "DATABASE_DB"
            valueFrom = "${var.rds_secret_arn}:db_name::"
          },
          {
            name      = "DATABASE_HOST"
            valueFrom = "${var.rds_secret_arn}:db_host::"
          },
          {
            name      = "DATABASE_PORT"
            valueFrom = "${var.rds_secret_arn}:db_port::"
          },
          {
            name      = "DATABASE_USER"
            valueFrom = "${var.rds_secret_arn}:db_username::"
          },
          {
            name      = "DATABASE_PASSWORD"
            valueFrom = "${var.rds_secret_arn}:db_password::"
          }
        ] : [],
        var.app_config_secret_arn != "" ? [
          {
            name      = "SECRET_KEY"
            valueFrom = "${var.app_config_secret_arn}:secret_key::"
          }
        ] : [],
        var.redis_secret_arn != "" ? [
          {
            name      = "REDIS_PASSWORD"
            valueFrom = "${var.redis_secret_arn}:auth_token::"
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "superset-init"
        }
      }

      essential = true
    }
  ])

  tags = var.tags
}

# Superset service task definition (long-running web server)
resource "aws_ecs_task_definition" "superset" {
  family                   = "${var.project_name}-${var.environment}-superset"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "superset"
      image = var.superset_image

      command = [
        "/bin/sh",
        "-c",
        <<-EOT
          set -e
          exec gunicorn \
            --bind 0.0.0.0:8088 \
            --access-logfile - \
            --error-logfile - \
            --workers 2 \
            --worker-class gthread \
            --threads 4 \
            --timeout 120 \
            --keep-alive 5 \
            --max-requests 1000 \
            --max-requests-jitter 50 \
            "superset.app:create_app()"
        EOT
      ]

      portMappings = [
        {
          containerPort = 8088
          protocol      = "tcp"
        }
      ]

      environment = concat(
        [
          {
            name  = "SUPERSET_LOAD_EXAMPLES"
            value = "no"
          }
        ],
        var.redis_host != "" ? [
          {
            name  = "REDIS_HOST"
            value = var.redis_host
          },
          {
            name  = "REDIS_PORT"
            value = tostring(var.redis_port)
          },
          {
            name  = "REDIS_SSL"
            value = "false"
          }
        ] : []
      )

      secrets = concat(
        var.rds_secret_arn != "" ? [
          {
            name      = "DATABASE_DB"
            valueFrom = "${var.rds_secret_arn}:db_name::"
          },
          {
            name      = "DATABASE_HOST"
            valueFrom = "${var.rds_secret_arn}:db_host::"
          },
          {
            name      = "DATABASE_PORT"
            valueFrom = "${var.rds_secret_arn}:db_port::"
          },
          {
            name      = "DATABASE_USER"
            valueFrom = "${var.rds_secret_arn}:db_username::"
          },
          {
            name      = "DATABASE_PASSWORD"
            valueFrom = "${var.rds_secret_arn}:db_password::"
          }
        ] : [],
        var.app_config_secret_arn != "" ? [
          {
            name      = "SECRET_KEY"
            valueFrom = "${var.app_config_secret_arn}:secret_key::"
          }
        ] : [],
        var.redis_secret_arn != "" ? [
          {
            name      = "REDIS_PASSWORD"
            valueFrom = "${var.redis_secret_arn}:auth_token::"
          }
        ] : [],
        var.snowflake_superset_secret_arn != "" ? [
          {
            name      = "SNOWFLAKE_ACCOUNT"
            valueFrom = "${var.snowflake_superset_secret_arn}:account::"
          },
          {
            name      = "SNOWFLAKE_USER"
            valueFrom = "${var.snowflake_superset_secret_arn}:user::"
          },
          {
            name      = "SNOWFLAKE_PRIVATE_KEY"
            valueFrom = "${var.snowflake_superset_secret_arn}:private_key::"
          },
          {
            name      = "SNOWFLAKE_ROLE"
            valueFrom = "${var.snowflake_superset_secret_arn}:role::"
          },
          {
            name      = "SNOWFLAKE_WAREHOUSE"
            valueFrom = "${var.snowflake_superset_secret_arn}:warehouse::"
          },
          {
            name      = "SNOWFLAKE_DATABASE"
            valueFrom = "${var.snowflake_superset_secret_arn}:database::"
          },
          {
            name      = "SNOWFLAKE_SCHEMA"
            valueFrom = "${var.snowflake_superset_secret_arn}:schema::"
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "superset"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8088/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = var.tags
}

# KMS key for ALB logs bucket encryption
resource "aws_kms_key" "alb_logs" {
  count = var.enable_load_balancer ? 1 : 0

  description             = "KMS key for ${var.project_name}-${var.environment} Superset ALB logs encryption"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = var.environment == "prod" ? true : false

  tags = merge(var.tags, {
    Purpose = "ALB logs encryption"
  })
}

resource "aws_kms_alias" "alb_logs" {
  count = var.enable_load_balancer ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-superset-alb-logs"
  target_key_id = aws_kms_key.alb_logs[0].key_id
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  count = var.enable_load_balancer ? 1 : 0

  bucket = "${var.project_name}-${var.environment}-superset-alb-logs"

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-superset-alb-logs"
    Purpose = "ALB access logs"
  })
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count = var.enable_load_balancer ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count = var.enable_load_balancer ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    expiration {
      days = var.environment == "prod" ? 90 : 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  count = var.enable_load_balancer ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count = var.enable_load_balancer ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.alb_logs[0].arn
    }
  }
}

# ALB service account IDs by region (for access logs)
# https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
locals {
  alb_service_account_ids = {
    us-east-1      = "127311923021"
    us-east-2      = "033677994240"
    us-west-1      = "027434742980"
    us-west-2      = "797873946194"
    eu-west-1      = "156460612806"
    eu-central-1   = "054676820928"
    ap-southeast-1 = "114774131450"
    ap-southeast-2 = "783225319266"
    ap-northeast-1 = "582318560864"
  }
}

data "aws_region" "current" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  count = var.enable_load_balancer ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${lookup(local.alb_service_account_ids, data.aws_region.current.name, "127311923021")}:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/*"
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs[0].arn
      }
    ]
  })
}

resource "aws_lb" "superset" {
  count = var.enable_load_balancer ? 1 : 0

  name               = "${var.project_name}-${var.environment}-superset-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs[0].id
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-superset-alb"
  })

  depends_on = [aws_s3_bucket_policy.alb_logs]
}

resource "aws_security_group" "alb" {
  count = var.enable_load_balancer ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-superset-alb-"
  vpc_id      = var.vpc_id

  #checkov:skip=CKV_AWS_260:Public web application requires HTTP access for redirect to HTTPS
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-superset-alb-sg"
  })
}

resource "aws_lb_target_group" "superset" {
  count = var.enable_load_balancer ? 1 : 0

  name        = "${var.project_name}-${var.environment}-superset-tg"
  port        = 8088
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = var.tags
}

resource "aws_lb_listener" "superset_http" {
  count = var.enable_load_balancer ? 1 : 0

  load_balancer_arn = aws_lb.superset[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.ssl_certificate_arn != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.ssl_certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.ssl_certificate_arn == "" ? aws_lb_target_group.superset[0].arn : null
  }
}

resource "aws_lb_listener" "superset_https" {
  count = var.enable_load_balancer && var.ssl_certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.superset[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.superset[0].arn
  }
}

resource "aws_ecs_service" "superset" {
  name            = "${var.project_name}-${var.environment}-superset"
  cluster         = aws_ecs_cluster.superset.id
  task_definition = aws_ecs_task_definition.superset.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [var.ecs_security_group_id]
    subnets          = var.public_subnet_ids
    assign_public_ip = true
  }

  dynamic "load_balancer" {
    for_each = var.enable_load_balancer ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.superset[0].arn
      container_name   = "superset"
      container_port   = 8088
    }
  }

  depends_on = [aws_lb_listener.superset_http]

  tags = var.tags
}
