# Display ELB IP address

 output "elb_dns_name" {
  value = "${aws_elb.aws-task-elb.dns_name}"
}
