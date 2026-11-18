############################################################
## F0 — outputs dos recursos que ja existem
############################################################

output "id_vpc" {
  value = aws_vpc.clc_vpc.id
}

output "igw_clc_vpc" {
  value = aws_internet_gateway.gw_clc_vpc.id
}

output "public_subnet_1a" {
  value = aws_subnet.public_subnet_1a.id
}

output "private_subnet_1a" {
  value = aws_subnet.private_subnet_1a.id
}

output "public_rt" {
  value = aws_route_table.public_rt.id
}

output "private_rt_1a" {
  value = aws_route_table.private_rt_1a.id
}

output "rt_pub_association_subnet_1a" {
  value = aws_route_table_association.rt_pub_association_subnet_1a.id
}

output "rt_priv_association_subnet_1a" {
  value = aws_route_table_association.rt_priv_association_subnet_1a.id
}

output "eip_nat_gw_1a" {
  value = aws_eip.eip_nat_gw_1a.id
}

output "nat_gw_1a" {
  value = aws_nat_gateway.nat_gw_1a.id
}

############################################################
## F1 — outputs das subnets 1c — ATIVOS
############################################################

output "public_subnet_1c" {
  value = aws_subnet.public_subnet_1c.id
}

output "private_subnet_1c" {
  value = aws_subnet.private_subnet_1c.id
}

############################################################
## F2 — output da associacao publica 1c — ATIVO
############################################################

output "rt_pub_association_subnet_1c" {
  value = aws_route_table_association.rt_pub_association_subnet_1c.id
}

############################################################
## F3 — outputs do EIP e NAT 1c — ATIVOS
############################################################

output "eip_nat_gw_1c" {
  value = aws_eip.eip_nat_gw_1c.id
}

output "nat_gw_1c" {
  value = aws_nat_gateway.nat_gw_1c.id
}

############################################################
## F4 — outputs da RT privada 1c e associacao — ATIVOS
############################################################

output "private_rt_1c" {
  value = aws_route_table.private_rt_1c.id
}

output "rt_priv_association_subnet_1c" {
  value = aws_route_table_association.rt_priv_association_subnet_1c.id
}

############################################################
## F5 — outputs da EC2 — ATIVOS
############################################################

output "web_sg" {
  value = aws_security_group.web_sg.id
}

output "web_server_id" {
  value = aws_instance.web_server.id
}

output "ec2_public_ip" {
  value = aws_instance.web_server.public_ip
}
