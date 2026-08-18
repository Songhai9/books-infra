output "aws_region" {
  description = "AWS region selected for this infrastructure."
  value       = var.aws_region
}

output "availability_zone" {
  description = "Availability Zone selected for the public subnet."
  value       = aws_subnet.public.availability_zone
}

output "vpc_id" {
  description = "ID of the Book Notes VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "app_security_group_id" {
  description = "ID of the application Security Group."
  value       = aws_security_group.app.id
}

output "app_instance_id" {
  description = "ID of the EC2 application host."
  value       = aws_instance.app.id
}

output "app_public_ip" {
  description = "Ephemeral public IPv4 address used to reach the application host."
  value       = aws_instance.app.public_ip
}

output "app_public_dns" {
  description = "Public DNS name assigned to the EC2 application host."
  value       = aws_instance.app.public_dns
}

output "ubuntu_ami_id" {
  description = "Latest official Ubuntu 24.04 x86_64 AMI selected at plan time."
  value       = data.aws_ami.ubuntu.id
}
