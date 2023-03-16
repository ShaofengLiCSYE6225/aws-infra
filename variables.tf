variable "profile" {
  type = string

}
variable "region" {
  type = string

}
variable "cidr" {
  type = string

}
variable "key_name" {
  type    = string
  default = "ec2"
}

variable "ami_id" {
  type = string
}
variable "route_name" {
  type    = string
  default = "prod.shaofengli.me"
}
variable "route_env" {
  type    = string
  default = "prod"
}

variable "route_zone_id" {
  type    = string
  default = "Z10080485ULCDC70ATMU"
}

variable "db_password" {
  type    = string
  default = "Lsf12345678!"
}