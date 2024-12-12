resource "aws_vpc" "vpn_vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "VPC-VPN"
  }
}

resource "aws_subnet" "vpn_subnet1" {
  vpc_id                                      = aws_vpc.vpn_vpc.id
  cidr_block                                  = "192.168.1.0/24"
  availability_zone                           = "us-east-1a"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch                     = true

  tags = {
    Name = "SubPubVPN1"
  }
}
resource "aws_subnet" "vpn_subnet2" {
  vpc_id                                      = aws_vpc.vpn_vpc.id
  cidr_block                                  = "192.168.2.0/24"
  availability_zone                           = "us-east-1b"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch                     = true

  tags = {
    Name = "SubPubVPN2"
  }
}
resource "aws_subnet" "vpn_subnet3" {
  vpc_id                                      = aws_vpc.vpn_vpc.id
  cidr_block                                  = "192.168.3.0/24"
  availability_zone                           = "us-east-1c"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch                     = true

  tags = {
    Name = "SubPubVPN3"
  }
}
resource "aws_subnet" "vpn_subnet4" {
  vpc_id                                      = aws_vpc.vpn_vpc.id
  cidr_block                                  = "192.168.4.0/24"
  availability_zone                           = "us-east-1d"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch                     = true

  tags = {
    Name = "SubPubVPN4"
  }
}

resource "aws_internet_gateway" "IGW-VPN" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    Name = "IGW-VPN"
  }
}

resource "aws_vpn_gateway" "vpn_gateway" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    Name = "VPGW-VPN"
  }
}

resource "aws_customer_gateway" "cg" {
  bgp_asn    = 65000
  ip_address = azurerm_public_ip.vpn_gateway_ip.ip_address
  type       = "ipsec.1"

  tags = {
    Name = "CGW-VPN"
  }
}

resource "aws_vpn_connection" "vpn_connection" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gateway.id
  customer_gateway_id = aws_customer_gateway.cg.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "VPN-AWS-AZURE"
  }
}

resource "aws_vpn_connection_route" "rota_vpnAZ1" {
  depends_on             = [aws_vpn_connection.vpn_connection]
  vpn_connection_id      = aws_vpn_connection.vpn_connection.id
  destination_cidr_block = "172.16.1.0/24"
}
resource "aws_vpn_connection_route" "rota_vpnAZ2" {
  depends_on             = [aws_vpn_connection.vpn_connection]
  vpn_connection_id      = aws_vpn_connection.vpn_connection.id
  destination_cidr_block = "172.16.2.0/24"
}

resource "aws_route_table" "vpn_route_table" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW-VPN.id
  }
  route {
    cidr_block = "172.16.1.0/24"
    gateway_id = aws_vpn_gateway.vpn_gateway.id
  }
  route {
    cidr_block = "172.16.2.0/24"
    gateway_id = aws_vpn_gateway.vpn_gateway.id
  }

  tags = {
    Name = "Rotas-VPN"
  }
}
resource "aws_vpn_gateway_route_propagation" "vpn_propagation" {
  depends_on     = [aws_vpn_gateway.vpn_gateway, aws_route_table.vpn_route_table]
  vpn_gateway_id = aws_vpn_gateway.vpn_gateway.id
  route_table_id = aws_route_table.vpn_route_table.id
}

resource "aws_route_table_association" "vpn_route_table_association1" {
  subnet_id      = aws_subnet.vpn_subnet1.id
  route_table_id = aws_route_table.vpn_route_table.id
}
resource "aws_route_table_association" "vpn_route_table_association2" {
  subnet_id      = aws_subnet.vpn_subnet2.id
  route_table_id = aws_route_table.vpn_route_table.id
}
resource "aws_route_table_association" "vpn_route_table_association3" {
  subnet_id      = aws_subnet.vpn_subnet3.id
  route_table_id = aws_route_table.vpn_route_table.id
}
resource "aws_route_table_association" "vpn_route_table_association4" {
  subnet_id      = aws_subnet.vpn_subnet4.id
  route_table_id = aws_route_table.vpn_route_table.id
}

resource "aws_instance" "lin_zabbix" {
  ami                         = "ami-0e001c9271cf7f3b9"
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.vpn_subnet1.id # Altere conforme necessário
  key_name                    = "vockey"                  # Altere conforme necessário
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.zab_sg.id]

  user_data_base64 = var.bootZab

  tags = {
    Name = "SRV-Monitoramento"
  }
}

resource "aws_security_group" "eks_sg" {
  name        = "EKS-SEC"
  description = "Permitir todos os protocolos necessarios para funcionamento do Cluster EKS"
  vpc_id      = aws_vpc.vpn_vpc.id

  #Libera HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }
  #Libera HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }
  ingress {
    from_port   = 10050
    to_port     = 10050
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/21"]
    description = "Zabbix"
  }
  ingress {
    from_port   = 10051
    to_port     = 10051
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/21"]
    description = "Zabbix Proxy"
  }
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/21"]
    description = "Kube API"
  }

  #Libera tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Saida"
  }
  tags = {
    Name = "EKS-SEC"
  }
}

resource "aws_security_group" "zab_sg" {
  name        = "ZAB-SEC"
  description = "Permitir todos os protocolos necessarios para funcionamento do Zabbix Server"
  vpc_id      = aws_vpc.vpn_vpc.id

  #Libera SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["193.186.4.239/32"]
    description = "SSH"
  }
  #Libera HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["193.186.4.239/32"]
    description = "HTTP"
  }
  #Libera HTTPS
  /*ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }*/
  ingress {
    from_port   = 10050
    to_port     = 10050
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/24","172.16.2.0/24"]
    description = "Zabbix"
  }
  ingress {
    from_port   = 10051
    to_port     = 10051
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/24","172.16.2.0/24"]
    description = "Zabbix Proxy"
  }
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/24","172.16.2.0/24"]
    description = "Kube API"
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["193.186.4.239/32"]
    description = "Grafana"
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["172.16.1.0/24","172.16.2.0/24"]
    description = "VPN Azure"
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    security_groups = [ aws_security_group.eks_sg ]
    description = "Interno EKS"
  }

  #Libera tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Saida"
  }
  tags = {
    Name = "ZAB-SEC"
  }
}
