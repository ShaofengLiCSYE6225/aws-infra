output "public_subnet" {
    value = aws_subnet.public_subnet
}
output "vpc_id" {
  value = aws_vpc.dev.id
}
