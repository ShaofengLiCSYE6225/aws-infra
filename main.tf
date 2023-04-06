module "dev" {
  source = "./module/dev"
  cidr   = var.cidr
}
data "aws_ami" "webapp_ami" {
  name_regex  = "csye6225-*"
  most_recent = true
}

data "template_file" "user_data" {
  #!/bin/bash
  template = <<EOF
  #!/bin/bash
  echo "DATABASE_HOST=${replace(aws_db_instance.csye6225.endpoint, "/:.*/", "")}" >> /home/ec2-user/.env
  echo "DATABASE_NAME=${aws_db_instance.csye6225.db_name}" >> /home/ec2-user/.env
  echo "DATABASE_USERNAME=${aws_db_instance.csye6225.username}" >> /home/ec2-user/.env
  echo "DATABASE_PASSWORD=${aws_db_instance.csye6225.password}" >> /home/ec2-user/.env
  echo "DIALECT=${aws_db_instance.csye6225.engine}" >> /home/ec2-user/.env 
  echo "AWS_BUCKET_NAME=${aws_s3_bucket.bucket.bucket}" >> /home/ec2-user/.env 
  echo "AWS_BUCKET_REGION=${var.region}" >> /home/ec2-user/.env 
  mv /home/ec2-user/.env /home/ec2-user/webapp/.env
  sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/tmp/cloudwatchconfig.json \
    -s
  EOF
}
resource "aws_lb_target_group" "alb_tg" {
  name        = "csye6225-lb-alb-tg"
  target_type = "instance"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.dev.vpc_id
  health_check {
    port     = 3000
    protocol = "HTTP"
    path     = "/healthz"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn

  }

}
resource "aws_launch_template" "lt" {
  name          = "asg_launch_config"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = "ec2"
  iam_instance_profile {
    name = aws_iam_instance_profile.CSYE6225.name
  }
  network_interfaces {
    security_groups             = [aws_security_group.web_sg.id]
    associate_public_ip_address = true
  }
  user_data = base64encode(data.template_file.user_data.rendered)

}
resource "aws_autoscaling_group" "asg" {
  name                = "csye6225-asg-spring2023"
  default_cooldown    = 60
  max_size            = 3
  min_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = module.dev.public_subnet.*.id
  target_group_arns   = [aws_lb_target_group.alb_tg.arn]
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "asg_launch_config"
    propagate_at_launch = true
  }
}
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "csye6225-asg-cpu-scale-up"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = 1
}
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "csye6225-asg-cpu-scale-down"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = -1
}
resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "csye6225-asg-scale-up-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  period              = 60
  namespace           = "AWS/EC2"
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "This metric monitors ec2 cpu utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_up.arn]
}
resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "csye6225-asg-scale-down-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  period              = 60
  namespace           = "AWS/EC2"
  statistic           = "Average"
  threshold           = 3
  alarm_description   = "This metric monitors ec2 cpu utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_down.arn]
}
resource "aws_route53_record" "dev" {
  zone_id = var.route_zone_id
  name    = var.route_name
  type    = "A"
  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true
  }
}
resource "aws_iam_instance_profile" "CSYE6225" {
  name = "instance_profile"
  role = aws_iam_role.EC2-CSYE6225.name
}
resource "aws_iam_policy" "policyone" {
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
  policy_arn = aws_iam_policy.policyone.arn
}

resource "aws_iam_role_policy_attachment" "policy" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# resource "aws_instance" "ec2" {
#   ami                         = var.ami_id
#   instance_type               = "t2.micro"
#   disable_api_termination     = false
#   subnet_id                   = module.dev.public_subnet.*.id[0]
#   vpc_security_group_ids      = [aws_security_group.web_sg.id]
#   associate_public_ip_address = true
#   disable_api_stop            = false
#   key_name                    = var.key_name
#   iam_instance_profile        = aws_iam_instance_profile.CSYE6225.name

#   user_data = <<EOF
#   #!/bin/bash
#   echo "DATABASE_HOST=${replace(aws_db_instance.csye6225.endpoint, "/:.*/", "")}" >> /home/ec2-user/.env
#   echo "DATABASE_NAME=${aws_db_instance.csye6225.db_name}" >> /home/ec2-user/.env
#   echo "DATABASE_USERNAME=${aws_db_instance.csye6225.username}" >> /home/ec2-user/.env
#   echo "DATABASE_PASSWORD=${aws_db_instance.csye6225.password}" >> /home/ec2-user/.env
#   echo "DIALECT=${aws_db_instance.csye6225.engine}" >> /home/ec2-user/.env 
#   echo "AWS_BUCKET_NAME=${aws_s3_bucket.bucket.bucket}" >> /home/ec2-user/.env 
#   echo "AWS_BUCKET_REGION=${var.region}" >> /home/ec2-user/.env 
#   mv /home/ec2-user/.env /home/ec2-user/webapp/.env
#   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
#     -a fetch-config \
#     -m ec2 \
#     -c file:/tmp/cloudwatchconfig.json \
#     -s
#   EOF
#   root_block_device {
#     volume_size = 50
#     volume_type = "gp2"
#   }

# }
resource "aws_lb" "load_balancer" {
  name               = "csye6225-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = module.dev.public_subnet.*.id
  tags = {
    application : "Webapp"
  }
}
resource "aws_security_group" "lb_sg" {
  name        = "load_balancer_sg"
  description = "lb security group"
  vpc_id      = module.dev.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

