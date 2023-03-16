module "dev" {
  source = "./module/dev"
  cidr   = var.cidr
}
data "aws_ami" "webapp_ami" {
  name_regex  = "csye6225-*"
  most_recent = true
}

resource "aws_route53_record" "dev" {
  zone_id = var.route_zone_id
  name    = var.route_name
  ttl     = 60
  type    = "A"
  records = [aws_instance.ec2.public_ip]
}
resource "aws_iam_instance_profile" "CSYE6225" {
  name = "instance_profile"
  role = aws_iam_role.EC2-CSYE6225.name
}
resource "aws_iam_policy" "policy" {
  name = "WebAppS3"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ],
          "Effect" : "Allow",
          "Resource" : [
            "arn:aws:s3:::${aws_s3_bucket.bucket.id}",
            "arn:aws:s3:::${aws_s3_bucket.bucket.id}/*"
          ]
        }
      ]
  })
}
resource "aws_iam_role_policy_attachment" "attachment" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = aws_iam_policy.policy.arn
}
resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "EC2-CSYE6225"
  }
}
resource "aws_db_subnet_group" "mydb" {
  name       = "mysql"
  subnet_ids = module.dev.private_subnet.*.id
}
resource "aws_security_group" "database" {
  name        = "database"
  description = "allow on port 3000"
  vpc_id      = module.dev.vpc_id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
resource "aws_s3_bucket" "bucket" {
  bucket        = "lsf-bucket-filesave${formatdate("YYYYMMDDhhmmss", timestamp())}"
  force_destroy = true
}
resource "aws_s3_bucket_lifecycle_configuration" "bucket-config" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id = "log"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_db_parameter_group" "mysql" {
  name        = "mysql-parameters"
  family      = "mysql5.7"
  description = "mysql5.7 parameter group"
}
resource "aws_db_instance" "csye6225" {
  allocated_storage      = 10
  db_name                = "csye6225"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  username               = "csye6225"
  password               = var.db_password
  parameter_group_name   = aws_db_parameter_group.mysql.name
  identifier             = "csye6225"
  skip_final_snapshot    = true
  multi_az               = false
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.mydb.name
  vpc_security_group_ids = [aws_security_group.database.id]
}
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
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
  }
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
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
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.CSYE6225.name

  user_data = <<EOF
  #!/bin/bash
  echo "DATABASE_HOST=${replace(aws_db_instance.csye6225.endpoint, "/:.*/", "")}" >> /home/ec2-user/.env
  echo "DATABASE_NAME=${aws_db_instance.csye6225.db_name}" >> /home/ec2-user/.env
  echo "DATABASE_USERNAME=${aws_db_instance.csye6225.username}" >> /home/ec2-user/.env
  echo "DATABASE_PASSWORD=${aws_db_instance.csye6225.password}" >> /home/ec2-user/.env
  echo "DIALECT=${aws_db_instance.csye6225.engine}" >> /home/ec2-user/.env 
  echo "AWS_BUCKET_NAME=${aws_s3_bucket.bucket.bucket}" >> /home/ec2-user/.env 
  echo "AWS_BUCKET_REGION=${var.region}" >> /home/ec2-user/.env 
  mv /home/ec2-user/.env /home/ec2-user/webapp/.env
  EOF
  root_block_device {
    volume_size = 50
    volume_type = "gp2"
  }

}

