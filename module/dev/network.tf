resource "aws_vpc" "dev" {
  cidr_block           = var.cidr
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnet" {
  count = 3
  vpc_id = "${aws_vpc.dev.id}"
  cidr_block = "${cidrsubnet(var.cidr,8,count.index)}"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Public Subnet-${count.index+0}"
  }
}
resource "aws_subnet" "private_subnet" {
  count = 3
  vpc_id = "${aws_vpc.dev.id}"
  cidr_block = "${cidrsubnet(var.cidr,8,count.index+4)}"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Private Subnet-${count.index+0}"
  }
}