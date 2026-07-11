resource "aws_kms_key" "rds" {
  description             = "Customer-managed key for RDS storage encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.app_name}-rds-kms"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.app_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = aws_subnet.data[*].id

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

resource "random_password" "db_master" {
  length      = 32
  special     = true
  # RDS disallows '/', '@', '"', and space in passwords
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.app_name}/rds/master-credentials"
  description             = "Master credentials for the wallet RDS instance"
  kms_key_id              = aws_kms_key.rds.arn
  recovery_window_in_days = 7

  tags = {
    Name = "${var.app_name}-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
  })
}

# Rotation is deliberately not wired to a custom Lambda here. In production this
# would deploy AWS's published SecretsManagerRDSPostgreSQLRotationSingleUser
# application from the Serverless Application Repository and attach it via
# aws_secretsmanager_secret_rotation { rotation_lambda_arn = ... }, on a 30-day
# schedule. Left as a documented next step rather than hand-rolled rotation code.

resource "aws_db_instance" "main" {
  identifier     = "${var.app_name}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                     = var.db_multi_az
  backup_retention_period      = var.db_backup_retention_days
  backup_window                = "03:00-04:00"
  maintenance_window           = "mon:04:30-mon:05:30"
  copy_tags_to_snapshot        = true
  deletion_protection          = var.environment == "production"
  skip_final_snapshot          = var.environment != "production"
  final_snapshot_identifier    = var.environment == "production" ? "${var.app_name}-final-snapshot" : null
  performance_insights_enabled = true

  tags = {
    Name = "${var.app_name}-db"
  }

  lifecycle {
    ignore_changes = [password]
  }
}
