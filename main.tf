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
  # Plateforme choisie.
  is_splunk    = var.observability_platform == "splunk"
  is_dynatrace = var.observability_platform == "dynatrace"
  # Le pool "observability" (ECK : Elasticsearch + Kibana) n'est justifie que
  # pour Elastic. Splunk/Dynatrace s'executent sur les noeuds existants.
  is_elastic = var.observability_platform == "elastic"

  # Etape 2 activee (couche d'observabilite + rollout restart).
  deploy_obs = var.deploy_observability_layer

  # Nombre de node pools resultant (2 pour Splunk/Dynatrace, 3 pour Elastic).
  # Sert d'information / de validation ; la logique reelle est dans azure-infra.
  node_pool_count = local.is_elastic ? 3 : 2

  # --- Auto-instrumentation OTel (Splunk / Elastic) -------------------------
  # Noms fixes partages avec les sous-modules (evite toute dependance de module
  # dans le calcul des annotations -> pas de cycle).
  splunk_collector_namespace = "splunk-otel"
  elastic_namespace          = "elastic-stack"

  # Stacks principales d'Easy Trade instrumentees en zero-code.
  otel_languages = ["java", "dotnet", "nodejs"]

  # Reference <namespace>/<instrumentation> selon la plateforme.
  instrumentation_ref = (
    local.is_splunk ? "${local.splunk_collector_namespace}/splunk-otel-collector" :
    local.is_elastic ? "${local.elastic_namespace}/opentelemetry-kube-stack" :
    null
  )

  # Annotations posees sur le namespace easytrade a l'Etape 2. Dynatrace n'en
  # utilise pas (injection par webhook cloudNativeFullStack).
  instrumentation_annotations = (
    local.deploy_obs && local.instrumentation_ref != null ?
    { for lang in local.otel_languages :
      "instrumentation.opentelemetry.io/inject-${lang}" => local.instrumentation_ref
    } :
    {}
  )

  # Hostnames publics deterministes bases sur l'IP statique de l'Ingress (nip.io
  # resout <ip>.nip.io -> <ip>, ce qui evite tout enregistrement DNS a gerer).
  ingress_ip     = module.azure_infra.ingress_public_ip
  easytrade_host = "easytrade.${local.ingress_ip}.nip.io"
  kibana_host    = "kibana.${local.ingress_ip}.nip.io"

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

# ------------------------------------------------------------------------------
# Etape 1 (suite) — Application Easy Trade (chart OCI), exposee via Ingress.
# Les annotations d'auto-instrumentation ne sont posees qu'a l'Etape 2.
# ------------------------------------------------------------------------------
module "kubernetes_apps" {
  source = "./modules/kubernetes-apps"

  namespace                = "easytrade"
  loadgen_enabled          = var.easytrade_loadgen_enabled
  problem_patterns_enabled = var.easytrade_problem_patterns_enabled

  # Pose a l'Etape 2 selon la plateforme (vide a l'Etape 1).
  instrumentation_annotations = local.instrumentation_annotations

  ingress_class_name  = module.azure_infra.ingress_class_name
  cluster_issuer_name = module.azure_infra.cluster_issuer_name
  hostname            = local.easytrade_host

  depends_on = [module.azure_infra]
}

# ==============================================================================
# Etape 2 — Couche d'observabilite (un seul module actif selon la plateforme,
# et uniquement si deploy_observability_layer = true).
# ==============================================================================

module "observability_splunk" {
  count  = local.deploy_obs && local.is_splunk ? 1 : 0
  source = "./modules/observability/splunk"

  cluster_name        = module.azure_infra.cluster_name
  collector_namespace = local.splunk_collector_namespace
  key_vault_name      = var.key_vault_name
  key_vault_rg        = var.key_vault_rg

  depends_on = [module.kubernetes_apps]
}

module "observability_dynatrace" {
  count  = local.deploy_obs && local.is_dynatrace ? 1 : 0
  source = "./modules/observability/dynatrace"

  easytrade_namespace = module.kubernetes_apps.namespace
  key_vault_name      = var.key_vault_name
  key_vault_rg        = var.key_vault_rg

  depends_on = [module.kubernetes_apps]
}

module "observability_elastic" {
  count  = local.deploy_obs && local.is_elastic ? 1 : 0
  source = "./modules/observability/elastic-eck"

  namespace           = local.elastic_namespace
  easytrade_namespace = module.kubernetes_apps.namespace
  ingress_class_name  = module.azure_infra.ingress_class_name
  cluster_issuer_name = module.azure_infra.cluster_issuer_name
  kibana_hostname     = local.kibana_host

  depends_on = [module.kubernetes_apps]
}
