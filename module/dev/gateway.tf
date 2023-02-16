resource "aws_internet_gateway" "dev_gateway" {
  vpc_id  = aws_vpc.dev.id
  tags = {
    Name = "dev vpc ig"
  }
}