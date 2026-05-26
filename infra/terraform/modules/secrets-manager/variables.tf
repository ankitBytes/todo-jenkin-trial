variable "project_name"      { type = string }
variable "environment"       { type = string }
variable "aws_region"        { type = string }
variable "account_id"        { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_issuer_host"  { type = string }

variable "namespace" {
  type    = string
  default = "todo"
}

variable "service_account" {
  type    = string
  default = "todo-backend-sa"
}

variable "db_host" {
  type      = string
  sensitive = true
}

variable "db_port" {
  type    = string
  default = "3306"
}

variable "db_user" { type = string }

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_name" { type = string }

variable "redis_host" {
  type      = string
  sensitive = true
}

variable "redis_port" {
  type    = string
  default = "6379"
}
