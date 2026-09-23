# 1. Cluster ECS
resource "aws_ecs_cluster" "dbt_cluster" {
  name = "dbt-execution-cluster"
}

# 2. Rôle IAM d'exécution (permet à ECS d'installer l'image depuis ECR et d'écrire les logs CloudWatch)
resource "aws_iam_role" "ecs_execution_role" {
  name = "dbt_ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 3. Rôle IAM de la tâche (donne au conteneur dbt l'accès à S3, Glue et Athena)
resource "aws_iam_role" "ecs_task_role" {
  name = "dbt_ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_s3" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "task_athena" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}

resource "aws_iam_role_policy_attachment" "task_glue" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}

# 4. Groupe de logs CloudWatch pour suivre les logs de dbt
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/dbt-runner"
  retention_in_days = 7
}

# 5. ECS Task Definition Fargate
resource "aws_ecs_task_definition" "dbt_task" {
  family                   = "dbt-run-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512" # 0.5 vCPU
  memory                   = "1024" # 1 GB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "dbt-container"
    image     = "${aws_ecr_repository.dbt_repo.repository_url}:latest"
    essential = true
    command   = ["run"] # Exécute dbt run au démarrage
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
        "awslogs-region"        = "eu-west-3"
        "awslogs-stream-prefix" = "dbt"
      }
    }
  }])
}