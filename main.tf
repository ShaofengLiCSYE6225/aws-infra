module "dev" {
  source = "./module/dev"
  cidr   = var.cidr
}
data "aws_ami" "webapp_ami" {
  name_regex  = "csye6225-*"
  most_recent = true
}
data "aws_key_pair" "ec2_key" {
  key_pair_id = var.key_pair_id
}
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "allow on port 3000"
  vpc_id      = module.dev.vpc_id
  ingress {
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
resource "aws_instance" "ec2" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  disable_api_termination     = false
  subnet_id                   = module.dev.public_subnet.*.id[0]
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  disable_api_stop            = false
  key_name                    = data.aws_key_pair.ec2_key.key_name
  root_block_device {
    volume_size = 50
    volume_type = "gp2"
  }
}

