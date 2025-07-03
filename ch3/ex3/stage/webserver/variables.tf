variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}
variable "server_port" {
  description = "The port on which the server will run"
  default     = 80
  type        = number
}