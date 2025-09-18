resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = concat(
            [
              for service in var.ecs_service_names : [
                ["AWS/ECS", "CPUUtilization", "ServiceName", service]
              ]
            ],
            [
              for service in var.ecs_service_names : [
                ["AWS/ECS", "MemoryUtilization", "ServiceName", service]
              ]
            ]
          )
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "ECS Resource Utilization"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = concat(
            [
              for func in var.lambda_function_names : [
                ["AWS/Lambda", "Duration", "FunctionName", func]
              ]
            ],
            [
              for func in var.lambda_function_names : [
                ["AWS/Lambda", "Errors", "FunctionName", func]
              ]
            ],
            [
              for func in var.lambda_function_names : [
                ["AWS/Lambda", "Invocations", "FunctionName", func]
              ]
            ]
          )
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Performance"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          metrics = var.data_lake_bucket_id != null ? [
            ["AWS/S3", "BucketSizeBytes", "BucketName", var.data_lake_bucket_id, "StorageType", "StandardStorage"],
            ["AWS/S3", "NumberOfObjects", "BucketName", var.data_lake_bucket_id, "StorageType", "AllStorageTypes"],
          ] : []
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "S3 Data Lake Metrics"
          period  = 86400
        }
      }
    ]
  })
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_subscription" "pagerduty" {
  count     = var.pagerduty_integration_key != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/${var.pagerduty_integration_key}/enqueue"
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  count               = length(var.ecs_service_names)
  alarm_name          = "${var.project_name}-${var.environment}-${var.ecs_service_names[count.index]}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = var.ecs_service_names[count.index]
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  count               = length(var.ecs_service_names)
  alarm_name          = "${var.project_name}-${var.environment}-${var.ecs_service_names[count.index]}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = var.ecs_service_names[count.index]
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = length(var.lambda_function_names)
  alarm_name          = "${var.project_name}-${var.environment}-${var.lambda_function_names[count.index]}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors Lambda function errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.lambda_function_names[count.index]
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count               = length(var.lambda_function_names)
  alarm_name          = "${var.project_name}-${var.environment}-${var.lambda_function_names[count.index]}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "25000" # 25 seconds
  alarm_description   = "This metric monitors Lambda function duration"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.lambda_function_names[count.index]
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  count               = length(var.api_gateway_names)
  alarm_name          = "${var.project_name}-${var.environment}-${var.api_gateway_names[count.index]}-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiName = var.api_gateway_names[count.index]
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  count               = length(var.api_gateway_names)
  alarm_name          = "${var.project_name}-${var.environment}-${var.api_gateway_names[count.index]}-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors API Gateway 5XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiName = var.api_gateway_names[count.index]
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "application_logs" {
  count             = length(var.log_group_names)
  name              = var.log_group_names[count.index]
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_metric_filter" "error_count" {
  count          = length(var.log_group_names)
  name           = "${var.project_name}-${var.environment}-error-count-${count.index}"
  log_group_name = aws_cloudwatch_log_group.application_logs[count.index].name
  pattern        = "ERROR"

  metric_transformation {
    name      = "${var.project_name}-${var.environment}-error-count"
    namespace = "${var.project_name}/${var.environment}/Logs"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "application_errors" {
  count               = length(var.log_group_names)
  alarm_name          = "${var.project_name}-${var.environment}-application-errors-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = aws_cloudwatch_log_metric_filter.error_count[count.index].metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.error_count[count.index].metric_transformation[0].namespace
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors application errors in logs"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

data "aws_region" "current" {}
