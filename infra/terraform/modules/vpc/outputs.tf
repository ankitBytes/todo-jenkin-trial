output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs, one per AZ"
  value       = aws_nat_gateway.main[*].id
}
