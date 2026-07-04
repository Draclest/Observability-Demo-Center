# ==============================================================================
# Demo Center Observabilite — assemblage racine
#
# Le deploiement se fait en deux temps (voir README) :
#   Etape 1 : infrastructure Azure + application Easy Trade (sans observabilite)
#   Etape 2 : couche d'observabilite de la plateforme choisie + rollout restart
#
# Les modules et leur cablage conditionnel sont ajoutes au fil des phases :
#   Phase 1 -> module.azure_infra
#   Phase 2 -> module.kubernetes_apps
#   Phase 3 -> module.observability (splunk | dynatrace | elastic-eck)
# ==============================================================================

locals {
  # Le pool "observability" (ECK : Elasticsearch + Kibana) n'est justifie que
  # pour Elastic. Splunk/Dynatrace s'executent sur les noeuds existants.
  is_elastic = var.observability_platform == "elastic"

  # Nombre de node pools resultant (2 pour Splunk/Dynatrace, 3 pour Elastic).
  # Sert d'information / de validation ; la logique reelle est dans azure-infra.
  node_pool_count = local.is_elastic ? 3 : 2

  # Tags communs a toutes les ressources de la demo.
  common_tags = merge(
    {
      project     = "demo-center-observabilite"
      platform    = var.observability_platform
      managed-by  = "terraform"
      environment = "demo"
    },
    var.tags,
  )
}

# ------------------------------------------------------------------------------
# Etape 1 — Infrastructure Azure : RG, reseau, AKS (pools conditionnels),
# Ingress Controller NGINX, cert-manager, alerte budget, auto-destroy.
# ------------------------------------------------------------------------------
module "azure_infra" {
  source = "./modules/azure-infra"

  subscription_id     = var.subscription_id
  location            = var.location
  resource_group_name = var.resource_group_name
  prefix              = var.prefix
  common_tags         = local.common_tags

  kubernetes_version       = var.kubernetes_version
  sku_system               = var.sku_system
  sku_easytrade            = var.sku_easytrade
  sku_observability        = var.sku_observability
  observability_node_count = var.observability_node_count
  is_elastic               = local.is_elastic

  allowed_ip_ranges = var.allowed_ip_ranges

  auto_destroy_ttl_hours = var.auto_destroy_ttl_hours
  budget_amount_eur      = var.budget_amount_eur
  budget_contact_emails  = var.budget_contact_emails
}
