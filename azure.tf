#GRUPO DE RECURSOS
resource "azurerm_resource_group" "grupo" {
  name     = "RG-VPN"
  location = "East US"
}


#VNET
resource "azurerm_virtual_network" "VNET-VPN" {
  name                = "VNET-VPN"
  address_space       = ["10.0.0.0/16", "172.16.0.0/16"]
  location            = "East US"
  resource_group_name = azurerm_resource_group.grupo.name
}

#SUBNET PUBLICA
resource "azurerm_subnet" "public1" {
  name                 = "SubredePub1-AZVPN"
  resource_group_name  = azurerm_resource_group.grupo.name
  virtual_network_name = azurerm_virtual_network.VNET-VPN.name
  address_prefixes     = ["172.16.1.0/24"]

}

#SUBNET DO GATEWAY
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.grupo.name
  virtual_network_name = azurerm_virtual_network.VNET-VPN.name
  address_prefixes     = ["172.16.0.0/27"]
}

# Criação do IP público estático para o VPN Gateway
resource "azurerm_public_ip" "vpn_gateway_ip" {
  name                = "vpn-gateway-ip"
  location            = azurerm_resource_group.grupo.location # Escolha a região adequada
  resource_group_name = azurerm_resource_group.grupo.name     # Nome do seu grupo de recursos
  allocation_method   = "Static"
  sku                 = "Standard" # Necessário para VPN Gateway
}

# Criação do Gateway de Rede Virtual (VPN Gateway)
resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = "VPGW-VPN-AZ"
  location            = "East US"                         # Escolha a região adequada
  resource_group_name = azurerm_resource_group.grupo.name # Nome do seu grupo de recursos
  type                = "Vpn"                             # Tipo de Gateway: VPN
  sku                 = "VpnGw1"                          # SKU do Gateway: VpnGw1
  active_active       = false
  enable_bgp          = false
  ip_configuration {
    name                          = "VPN-Gateway-IP-Config"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }
}

resource "azurerm_route_table" "Rota_AWS" {
  name                = "TabelaRotas_VPN"
  location            = azurerm_resource_group.grupo.location
  resource_group_name = azurerm_resource_group.grupo.name

  route {
    name           = "Rota1"
    address_prefix = "192.168.1.0/24"
    next_hop_type  = "VirtualNetworkGateway"
  }
  route {
    name           = "Rota2"
    address_prefix = "192.168.2.0/24"
    next_hop_type  = "VirtualNetworkGateway"
  }
}

/*resource "azurerm_subnet_route_table_association" "Associacao_tabela" {
  subnet_id      = azurerm_subnet.public1.id
  route_table_id = azurerm_route_table.Rota_AWS.id
}*/

resource "azurerm_local_network_gateway" "GTW-LOCAL01" {
  name                = "GTW-LOCAL01"
  location            = azurerm_resource_group.grupo.location
  resource_group_name = azurerm_resource_group.grupo.name

  gateway_address = aws_vpn_connection.vpn_connection.tunnel1_address
  address_space = [
    aws_subnet.vpn_subnet1.cidr_block,
    aws_subnet.vpn_subnet2.cidr_block
  ]
}

resource "azurerm_local_network_gateway" "GTW-LOCAL02" {
  name                = "GTW-LOCAL02"
  location            = azurerm_resource_group.grupo.location
  resource_group_name = azurerm_resource_group.grupo.name

  gateway_address = aws_vpn_connection.vpn_connection.tunnel2_address
  address_space = [
    aws_subnet.vpn_subnet1.cidr_block,
    aws_subnet.vpn_subnet2.cidr_block
  ]
}

resource "azurerm_virtual_network_gateway_connection" "CONEXAO-01" {
  name                       = "CONEXAO-AWS01"
  location                   = azurerm_resource_group.grupo.location
  resource_group_name        = azurerm_resource_group.grupo.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.GTW-LOCAL01.id
  # AWS VPN Connection secret shared key
  shared_key = aws_vpn_connection.vpn_connection.tunnel1_preshared_key
}


resource "azurerm_virtual_network_gateway_connection" "CONEXAO-02" {
  name                       = "CONEXAO-AWS02"
  location                   = azurerm_resource_group.grupo.location
  resource_group_name        = azurerm_resource_group.grupo.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.GTW-LOCAL02.id
  # AWS VPN Connection secret shared key
  shared_key = aws_vpn_connection.vpn_connection.tunnel2_preshared_key
}

resource "random_pet" "azurerm_kubernetes_cluster_dns_prefix" {
  prefix = "dns"
}

resource "azurerm_kubernetes_cluster" "default" {
  depends_on          = [azurerm_virtual_network.VNET-VPN]
  name                = "Cluster-AKS"
  location            = azurerm_resource_group.grupo.location
  resource_group_name = azurerm_resource_group.grupo.name
  dns_prefix          = "${random_pet.azurerm_kubernetes_cluster_dns_prefix.prefix}-k8s"
  kubernetes_version  = "1.29.10"
  node_resource_group = "AKS-NodesRG"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                 = "agentpool"
    vm_size              = "Standard_B2S"
    min_count            = 1
    max_count            = 2
    node_count           = 2
    auto_scaling_enabled = true
    max_pods             = 30
    vnet_subnet_id       = azurerm_subnet.public1.id
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
}