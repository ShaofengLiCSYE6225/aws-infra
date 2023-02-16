resource "aws_route_table_association" "public_ass" {
  count = 3
  subnet_id = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public_second_rt.id
}
resource "aws_route_table_association" "private_ass" {
  count = 3
  subnet_id = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private_second_rt.id
}