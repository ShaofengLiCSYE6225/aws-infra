output "public_subnet" {
    value = aws_subnet.public_subnet
}
output "private_subnet" {
  value = aws_subnet.private_subnet
}
output "vpc_id" {
  value = aws_vpc.dev.id
}
