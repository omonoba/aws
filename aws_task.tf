
# Configure AWS connection, secrets are in terraform.tfvars
provider "aws" {
  region     = "${var.region}"
}

resource "aws_vpc" "main" {
  cidr_block       = "${var.vpc_cidr}"
  instance_tenancy = "default"

  tags {
    Name = "main"
    Location = "Stockholm"
  }
}

resource "aws_subnet" "task_subnets" {
  count = "${length(var.subnet_cidr)}"
  availability_zone = "${element(data.aws_availability_zones.azs.names, count.index)}"
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "${element(var.subnet_cidr, count.index)}"
  map_public_ip_on_launch = true

}

data "aws_subnet_ids" "subnet_ids" {
  vpc_id = "${aws_vpc.main.id}"
}


resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.main.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
 route_table_id         = "${aws_vpc.main.main_route_table_id}"
 destination_cidr_block = "0.0.0.0/0"
 gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create autoscaling policy -> target at a 75% average CPU load
resource "aws_autoscaling_policy" "aws-task-asg-policy-1" {
  name                   = "aws-task-asg-policy"
  policy_type            = "TargetTrackingScaling"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = "${aws_autoscaling_group.aws-task-asg.name}"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 75.0
  }
}

# Create an autoscaling group
resource "aws_autoscaling_group" "aws-task-asg" {
  name = "aws-task-asg"
  launch_configuration = "${aws_launch_configuration.aws-task-lc.id}"
  vpc_zone_identifier = ["${data.aws_subnet_ids.subnet_ids.ids}"]
#  availability_zones = ["${data.aws_availability_zones.azs.names}"]

  min_size = 1
  max_size = 4

  load_balancers = ["${aws_elb.aws-task-elb.name}"]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "aws-task-ASG"
    propagate_at_launch = true
  }
}

# Create launch configuration
resource "aws_launch_configuration" "aws-task-lc" {
  name = "aws-task-lc"
  image_id = "${lookup(var.aws_amis, var.region)}"
  instance_type = "t2.micro"
#  key_name = "${var.key_name}"
  security_groups = ["${aws_security_group.aws-task-lc-sg.id}"]

#  iam_instance_profile = "${var.iam_instance_profile}"

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              yum install httpd php php-mysql -y
              sudo service httpd start
              sudo chkconfig httpd on
              echo "<?php phpinfo();?>" > /var/www/html/index.php
              cd /var/www/html
              wget https://s3.eu-west-2.amazonaws.com/acloudguru-example/connect.php
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Create the ELB
resource "aws_elb" "aws-task-elb" {
  name = "aws-task-elb"
  security_groups = ["${aws_security_group.aws-task-elb-sg.id}"]
  subnets = ["${data.aws_subnet_ids.subnet_ids.ids}"]
#  availability_zones = ["${data.aws_availability_zones.azs.names}"]


  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    #target = "TCP:${var.server_port}"
    target = "HTTP:${var.server_port}/index.php"
  }

  # This adds a listener for incoming HTTP requests.
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }
}

# Create security group that's applied the launch configuration
resource "aws_security_group" "aws-task-lc-sg" {
  name = "aws-task-lc-sg"
  vpc_id = "${aws_vpc.main.id}"

  # Inbound HTTP from anywhere
  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "${var.ssh_port}"
    to_port = "${var.ssh_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create security group that's applied to the ELB
resource "aws_security_group" "aws-task-elb-sg" {
  name = "aws-task-elb-sg"
  vpc_id = "${aws_vpc.main.id}"

  # Allow all outbound
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from anywhere
  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
