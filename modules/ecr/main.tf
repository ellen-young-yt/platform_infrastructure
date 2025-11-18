resource "aws_ecr_repository" "dbt_project" {
  name = "${var.project_name}-${var.environment}-dbt"

  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.dbt_ecr_key.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-dbt-ecr"
  })
}

resource "aws_kms_key" "dbt_ecr_key" {
  description             = "KMS key for dbt ECR repository encryption"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-dbt-ecr-kms-key"
  })
}

resource "aws_kms_alias" "dbt_ecr_key" {
  name          = "alias/${var.project_name}-${var.environment}-dbt-ecr"
  target_key_id = aws_kms_key.dbt_ecr_key.key_id
}

resource "aws_ecr_lifecycle_policy" "dbt_project" {
  repository = aws_ecr_repository.dbt_project.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Superset ECR repository
# checkov:skip=CKV_AWS_51: Superset uses 'latest' tag in deployment workflow, requires mutable tags
resource "aws_ecr_repository" "superset" {
  name = "${var.project_name}-${var.environment}-superset"

  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.superset_ecr_key.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-superset-ecr"
  })
}

resource "aws_kms_key" "superset_ecr_key" {
  description             = "KMS key for Superset ECR repository encryption"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-superset-ecr-kms-key"
  })
}

resource "aws_kms_alias" "superset_ecr_key" {
  name          = "alias/${var.project_name}-${var.environment}-superset-ecr"
  target_key_id = aws_kms_key.superset_ecr_key.key_id
}

resource "aws_ecr_lifecycle_policy" "superset" {
  repository = aws_ecr_repository.superset.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 3 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Airflow ECR repository
# checkov:skip=CKV_AWS_51: Airflow uses 'latest' tag in deployment workflow, requires mutable tags
resource "aws_ecr_repository" "airflow" {
  name = "${var.project_name}-${var.environment}-airflow"

  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.airflow_ecr_key.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-airflow-ecr"
  })
}

resource "aws_kms_key" "airflow_ecr_key" {
  description             = "KMS key for Airflow ECR repository encryption"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-airflow-ecr-kms-key"
  })
}

resource "aws_kms_alias" "airflow_ecr_key" {
  name          = "alias/${var.project_name}-${var.environment}-airflow-ecr"
  target_key_id = aws_kms_key.airflow_ecr_key.key_id
}

resource "aws_ecr_lifecycle_policy" "airflow" {
  repository = aws_ecr_repository.airflow.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 3 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
