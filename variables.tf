#AWS region
variable "aws_region" {
  type = "string"
  default = "ca-central-1"
}

variable "vpc_id" {}

#obtain the default VPC id
data "aws_vpc" "default" {
  default = true
}