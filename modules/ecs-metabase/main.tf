resource "aws_ecs_cluster" "metabase" {
  name = "${var.project_name}-${var.environment}-metabase"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-metabase-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "metabase" {
  cluster_name = aws_ecs_cluster.metabase.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_iam_role" "metabase_execution" {
  name = "${var.project_name}-${var.environment}-metabase-execution-role"

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

resource "aws_iam_role_policy_attachment" "metabase_execution" {
  role       = aws_iam_role.metabase_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "metabase_task" {
  name = "${var.project_name}-${var.environment}-metabase-task-role"

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

resource "aws_iam_role_policy" "metabase_task" {
  name = "${var.project_name}-${var.environment}-metabase-task-policy"
  role = aws_iam_role.metabase_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

resource "aws_cloudwatch_log_group" "metabase" {
  name              = "/ecs/${var.project_name}-${var.environment}-metabase"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_ecs_task_definition" "metabase" {
  family                   = "${var.project_name}-${var.environment}-metabase"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.metabase_execution.arn
  task_role_arn            = aws_iam_role.metabase_task.arn

  container_definitions = jsonencode([
    {
      name  = "metabase"
      image = var.metabase_image

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "MB_DB_TYPE"
          value = var.database_type
        },
        {
          name  = "MB_DB_CONNECTION_URI"
          value = var.database_connection_uri
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.metabase.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "metabase"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:3000/api/health || exit 1"
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

resource "aws_lb" "metabase" {
  count = var.enable_load_balancer ? 1 : 0

  name               = "${var.project_name}-${var.environment}-metabase-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-metabase-alb"
  })
}

resource "aws_security_group" "alb" {
  count = var.enable_load_balancer ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-metabase-alb-"
  vpc_id      = var.vpc_id

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
    Name = "${var.project_name}-${var.environment}-metabase-alb-sg"
  })
}

resource "aws_lb_target_group" "metabase" {
  count = var.enable_load_balancer ? 1 : 0

  name        = "${var.project_name}-${var.environment}-metabase-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = var.tags
}

resource "aws_lb_listener" "metabase" {
  count = var.enable_load_balancer ? 1 : 0

  load_balancer_arn = aws_lb.metabase[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.metabase[0].arn
  }
}

resource "aws_ecs_service" "metabase" {
  name            = "${var.project_name}-${var.environment}-metabase"
  cluster         = aws_ecs_cluster.metabase.id
  task_definition = aws_ecs_task_definition.metabase.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [var.ecs_security_group_id]
    subnets         = var.private_subnet_ids
  }

  dynamic "load_balancer" {
    for_each = var.enable_load_balancer ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.metabase[0].arn
      container_name   = "metabase"
      container_port   = 3000
    }
  }

  depends_on = [aws_lb_listener.metabase]

  tags = var.tags
}

data "aws_region" "current" {}
