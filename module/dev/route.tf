resource "aws_route_table" "public_second_rt" {
 vpc_id = aws_vpc.dev.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.dev_gateway.id
 }
 
 tags = {
   Name = "public 2nd Route Table"
 }
}
resource "aws_route_table" "private_second_rt" {
 vpc_id = aws_vpc.dev.id
 
 route =[]
 
 tags = {
   Name = "private 2nd Route Table"
 }
}