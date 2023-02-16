variable "profile" {
  type = string
}
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "cidr" {
  type    = string
  default = "10.0.0.0/16"
}