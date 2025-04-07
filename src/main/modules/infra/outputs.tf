output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "lambda_sg_id" {
  description = "ID of Lambda security group"
  value       = aws_security_group.lambda.id
}

output "postgres_sg_id" {
  description = "ID of PostgreSQL security group"
  value       = aws_security_group.postgres.id
}

output "jumpbox_id" {
  description = "ID of jumpbox instance (if created)"
  value       = var.create_jumpbox ? aws_instance.jumpbox[0].id : null
}

output "jumpbox_private_ip" {
  description = "Private IP of jumpbox instance (if created)"
  value       = var.create_jumpbox ? aws_instance.jumpbox[0].private_ip : null
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = data.aws_availability_zones.available.names
}