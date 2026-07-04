# ==============================================================================
# Resource group, reseau et cluster AKS
# ==============================================================================

resource "azurerm_resource_group" "demo" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.common_tags
}

# --- Reseau -----------------------------------------------------------------

resource "azurerm_virtual_network" "demo" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  address_space       = ["10.0.0.0/16"]
  tags                = var.common_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.0.0.0/20"]
}

# --- Cluster AKS ------------------------------------------------------------
# Pool "system" : composants systeme uniquement (taint CriticalAddonsOnly via
# only_critical_addons_enabled), pour forcer Easy Trade sur le pool easytrade.
# Autoscaling desactive sur tous les pools (comportement previsible en demo).

resource "azurerm_kubernetes_cluster" "demo" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  dns_prefix          = "${var.prefix}-aks"
  kubernetes_version  = var.kubernetes_version

  # Regroupe les ressources gerees par AKS (dont les Load Balancers/IP) dans un
  # RG dedie, lui-meme supprime avec le cluster.
  node_resource_group = "${var.resource_group_name}-aks-nodes"

  default_node_pool {
    name                         = "system"
    vm_size                      = var.sku_system
    node_count                   = 1
    only_critical_addons_enabled = true
    vnet_subnet_id               = azurerm_subnet.aks.id
    orchestrator_version         = var.kubernetes_version
    tags                         = var.common_tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
    service_cidr        = "10.1.0.0/16"
    dns_service_ip      = "10.1.0.10"
    pod_cidr            = "10.244.0.0/16"
  }

  tags = var.common_tags
}

# --- Pool easytrade (toujours present) --------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "easytrade" {
  name                  = "easytrade"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.demo.id
  vm_size               = var.sku_easytrade
  node_count            = 1
  mode                  = "User"
  orchestrator_version  = var.kubernetes_version
  vnet_subnet_id        = azurerm_subnet.aks.id

  node_labels = {
    workload = "easytrade"
  }

  tags = var.common_tags
}

# --- Pool observability (Elastic uniquement) --------------------------------
# Taint dedie pour reserver ces noeuds a ECK (Elasticsearch + Kibana).

resource "azurerm_kubernetes_cluster_node_pool" "observability" {
  count = var.is_elastic ? 1 : 0

  name                  = "obsvblty"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.demo.id
  vm_size               = var.sku_observability
  node_count            = var.observability_node_count
  mode                  = "User"
  orchestrator_version  = var.kubernetes_version
  vnet_subnet_id        = azurerm_subnet.aks.id

  node_labels = {
    workload = "observability"
  }
  node_taints = ["workload=observability:NoSchedule"]

  tags = var.common_tags
}
