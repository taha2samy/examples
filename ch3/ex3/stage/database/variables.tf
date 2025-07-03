variable "db_username" {
  description = "The username for the database"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "The password for the database"
  type        = string
  default     = "password123"
}
variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}