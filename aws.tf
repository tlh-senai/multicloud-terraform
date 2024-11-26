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

resource "aws_vpn_connection_route" "rota_vpnAZ" {
  depends_on             = [aws_vpn_connection.vpn_connection]
  vpn_connection_id      = aws_vpn_connection.vpn_connection.id
  destination_cidr_block = "172.16.1.0/24"
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

resource "aws_instance" "lin_zabbix" {
  ami                         = "ami-0e001c9271cf7f3b9"
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.vpn_subnet1.id # Altere conforme necessário
  key_name                    = "vockey"                  # Altere conforme necessário
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.zab_sg.id]

  user_data = <<-EOF
  #!/bin/bash

  sudo su -
  # Instalar o zabbix
  wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu22.04_all.deb
  dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb

  # Atualizar o sources list e baixar as dependências necessárias
  apt update -y
  apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent mysql-server -y

  #Configuração do banco de dados
  mysql -u root --password="" -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
  mysql -u root --password="" -e "create user zabbix@localhost identified by 'Senai@134';"
  mysql -u root --password="" -e "grant all privileges on zabbix.* to zabbix@localhost;"
  mysql -u root --password="" -e "set global log_bin_trust_function_creators = 1;"

  zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix --password="Senai@134" zabbix

  mysql -u root --password="" -e "set global log_bin_trust_function_creators = 0;"

  # Substituir a senha no arquivo de configuração
  sed -i '129s/# DBPassword=/DBPassword=Senai@134/' /etc/zabbix/zabbix_server.conf

  # Reiniciar os serviços
  systemctl restart zabbix-server.service zabbix-agent.service apache2.service
  systemctl enable zabbix-server.service zabbix-agent.service apache2.service
  
  # Adicionar DNS da AWS e da Google
  sed -i '1inameserver 8.8.8.8' /etc/resolv.conf && sed -i '1inameserver 169.254.169.253' /etc/resolv.conf
  systemctl restart systemd.resolved

  # Instalar o AWSCLI e o KubeCTL
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  apt install unzip -y
  unzip awscliv2.zip
  sudo ./aws/install

  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

  ## Instalação do Grafana
  # Instalar pacotes necessários
  apt-get install -y adduser libfontconfig1 musl

  # Instalar o Grafana
  wget https://dl.grafana.com/oss/release/grafana_10.4.1_amd64.deb
  dpkg -i grafana_10.4.1_amd64.deb

  # Instalar o plugin de instalação com o Zabbix
  grafana-cli plugins install alexanderzobnin-zabbix-app

  # Reiniciar serviço
  systemctl restart grafana-server
  systemctl enable grafana-server
EOF

  tags = {
    Name = "SRV-Monitoramento"
  }
}

resource "aws_security_group" "zab_sg" {
  name        = "Sec-Monitor"
  description = "Permitir SSH, HTTP, HTTPS, Zabbix, Zabbix Agent, K8S API, Grafana e comunicar com Azure"
  vpc_id      = aws_vpc.vpn_vpc.id

  #Libera SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }
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
    cidr_blocks = ["0.0.0.0/0"]
    description = "Zabbix"
  }
  ingress {
    from_port   = 10051
    to_port     = 10051
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Zabbix Proxy"
  }
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kube API"
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana"
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["172.16.1.0/24"]
    description = "VPN Azure"
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
    Name = "Sec-Zabbix"
  }
}

output "ipzabbix" {
  value = aws_instance.lin_zabbix.public_ip
}
output "ipprivzab" {
  value = aws_instance.lin_zabbix.private_ip
}
output "urlzabbix" {
  value = "http://${aws_instance.lin_zabbix.public_ip}/zabbix"
}
output "urlgrafana" {
  value = "http://${aws_instance.lin_zabbix.public_ip}:3000"
}