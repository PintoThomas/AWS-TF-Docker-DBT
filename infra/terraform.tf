terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      project     = var.project_name
      Environment = "dev"
    }
  }
}

# ------------------------------------------------------------------------------
# 1. Buckets S3 (Données Brutes & Données Transformées)
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "raw_data" {
  bucket        = "${var.project_name}-raw-data"
  force_destroy = true
}

resource "aws_s3_bucket" "marts_data" {
  bucket        = "${var.project_name}-marts-data"
  force_destroy = true
}

# Block public access sur les deux buckets
resource "aws_s3_bucket_public_access_block" "raw_data_block" {
  bucket                  = aws_s3_bucket.raw_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "marts_data_block" {
  bucket                  = aws_s3_bucket.marts_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# 2. Amazon ECR (Registry pour l'image Docker dbt)
# ------------------------------------------------------------------------------
resource "aws_ecr_repository" "dbt_repo" {
  name                 = "${var.project_name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ------------------------------------------------------------------------------
# 3. AWS IAM Role (Pour l'exécution de dbt via Athena / Glue / S3)
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# Politique de Trust (Assume Role) séparée en 2 statements distincts
data "aws_iam_policy_document" "dbt_assume_role" {
  # Statement 1 : Services AWS automatisés (ECS, CodeBuild)
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com", "codebuild.amazonaws.com"]
    }
  }

  # Statement 2 : Exécution locale / Dev avec votre identité AWS actuelle
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }
  }
}

resource "aws_iam_role" "dbt_execution_role" {
  name               = "${var.project_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.dbt_assume_role.json
}

# Politique de permissions pour dbt (Athena, Glue Data Catalog, S3)
resource "aws_iam_policy" "dbt_policy" {
  name        = "${var.project_name}-policy"
  description = "Permissions necessaires pour dbt-athena (S3, Glue Catalog, Athena)"

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
          aws_s3_bucket.raw_data.arn,
          "${aws_s3_bucket.raw_data.arn}/*",
          aws_s3_bucket.marts_data.arn,
          "${aws_s3_bucket.marts_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateDatabase",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dbt_attach" {
  role       = aws_iam_role.dbt_execution_role.name
  policy_arn = aws_iam_policy.dbt_policy.arn
}