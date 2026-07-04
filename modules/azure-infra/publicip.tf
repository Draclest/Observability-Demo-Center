# ==============================================================================
# IP publique statique de l'Ingress Controller
#
# Allouer l'IP en amont (plutot que de la laisser attribuer dynamiquement par le
# Service LoadBalancer) permet :
#   - de construire des URLs deterministes (hostnames nip.io) exposees en output ;
#   - d'eviter la collision entre les Ingress Easy Trade et Kibana (routage par
#     host distinct au lieu de deux regles "/" concurrentes).
# L'identite du cluster AKS recoit "Network Contributor" sur cette IP pour que le
# Load Balancer puisse l'attacher.
# ==============================================================================

resource "azurerm_public_ip" "ingress" {
  name                = "${var.prefix}-ingress-pip"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.common_tags
}

resource "azurerm_role_assignment" "aks_ingress_ip" {
  scope                = azurerm_public_ip.ingress.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.demo.identity[0].principal_id
}
