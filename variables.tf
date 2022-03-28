variable "secret_arn" {
  type        = string
  description = "Secret ARN from which to retrive credentials"
  default     = "arn:aws:secretsmanager:eu-central-1:780582450272:secret:nginx-KrlsLy"
}

variable "local_output" {
  type        = bool
  description = "Exports ssh credentials to local storage (Caution: credentials end up on backend tfstate)"
  default     = true
}

variable "default_ami" {
  type    = string
  default = "ami-0cc0a36f626a4fdf5"
}

variable "instance_type" {
  type    = string
  default = "t2.small"
}

variable "nginx_white_list_ips" {
  type = list(string)
  default = [
    "10.0.0.0/16",       // VPC
  ]
}

variable "nginx_white_list_ips_private" {
  type = list(string)
  default = [
    "79.208.23.156/32",  // Tamer
  ]
}

variable "nginx_port" {
  type    = number
  default = 8765
}
