variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. staging, production)"
  type        = string
  default     = "staging"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway instead of one per AZ, to control cost pre-production"
  type        = bool
  default     = true
}

variable "app_name" {
  description = "Short name for the service, used in resource naming"
  type        = string
  default     = "wallet-app"
}

variable "container_image" {
  description = "Container image (repository:tag) for the app service"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:1.27-alpine"
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8080
}

variable "app_task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 512
}

variable "app_task_memory" {
  description = "Fargate task memory (MB)"
  type        = number
  default     = 1024
}

variable "app_desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 2
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.4"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB for RDS"
  type        = number
  default     = 50
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "wallet"
}

variable "db_username" {
  description = "Master username for RDS (password is generated and stored in Secrets Manager)"
  type        = string
  default     = "wallet_admin"
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated RDS backups"
  type        = number
  default     = 14
}

variable "db_multi_az" {
  description = "Whether to deploy RDS in Multi-AZ mode"
  type        = bool
  default     = true
}
