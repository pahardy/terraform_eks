#AWS region
variable "aws_region" {
  type = string
  default = "ca-central-1"
}

variable "vpc_cidr" {
  type = string
  description = "CIDR for the VPC"
  default = "10.0.0.0/16"
}
