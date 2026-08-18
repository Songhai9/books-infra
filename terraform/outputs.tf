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
