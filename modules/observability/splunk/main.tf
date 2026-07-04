# ==============================================================================
# Splunk : Splunk Distribution of OpenTelemetry Collector + OTel Operator
#
# - Collector en DaemonSet sur tous les noeuds (metriques/traces/logs).
# - OTel Operator upstream active (operator.enabled) pour l'auto-instrumentation
#   zero-code : le chart cree une ressource Instrumentation nommee
#   "splunk-otel-collector" dans le namespace du collector. L'injection est
#   declenchee par les annotations posees sur le namespace easytrade (Etape 2)
#   qui referencent cette Instrumentation.
# - Destination : Splunk Observability Cloud (access token + realm depuis KV).
# ==============================================================================

# --- Credentials depuis le Key Vault persistant -----------------------------

data "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_rg
}

data "azurerm_key_vault_secret" "access_token" {
  name         = "splunk-access-token"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "realm" {
  name         = "splunk-realm"
  key_vault_id = data.azurerm_key_vault.kv.id
}

# --- Namespace du collector -------------------------------------------------

resource "kubernetes_namespace" "splunk" {
  metadata {
    name = var.collector_namespace
  }
}

# --- Splunk OTel Collector + OTel Operator ----------------------------------

resource "helm_release" "splunk_otel" {
  name       = "splunk-otel-collector"
  repository = "https://signalfx.github.io/splunk-otel-collector-chart"
  chart      = "splunk-otel-collector"
  version    = var.chart_version
  namespace  = kubernetes_namespace.splunk.metadata[0].name

  atomic  = true
  timeout = 600

  values = [yamlencode({
    clusterName = var.cluster_name

    splunkObservability = {
      realm = data.azurerm_key_vault_secret.realm.value
    }

    # Destination Observability Cloud uniquement (pas de Splunk Platform).
    splunkPlatform = {
      endpoint = ""
      token    = ""
    }

    # OTel Operator upstream pour l'auto-instrumentation zero-code.
    operator = {
      enabled = true
    }
    operatorcrds = {
      install = true
    }

    # cert-manager est deja installe par le module azure-infra : on desactive
    # celui embarque par le chart pour eviter un doublon.
    certmanager = {
      enabled = false
    }
  })]

  # Access token passe en set_sensitive pour ne pas apparaitre en clair.
  set_sensitive {
    name  = "splunkObservability.accessToken"
    value = data.azurerm_key_vault_secret.access_token.value
  }
}
