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