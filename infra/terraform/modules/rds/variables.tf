variable "project_name" { type = string }
variable "environment" { type = string }
variable "identifier" { type = string }
variable "instance_class" { type = string }
variable "db_name" { type = string }
variable "username" { type = string }
variable "password" {
  type      = string
  sensitive = true
}
variable "allocated_storage" { type = number }
variable "backup_retention" { type = number }
variable "multi_az" { type = bool }
variable "deletion_protection" { type = bool }
variable "skip_final_snapshot" { type = bool }
variable "private_subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
 