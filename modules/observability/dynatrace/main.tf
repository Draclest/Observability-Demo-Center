# ==============================================================================
# Dynatrace : Dynatrace Operator en mode cloudNativeFullStack (injection par pod)
#
# - Deploiement de l'operateur via Helm (OCI).
# - Secret contenant l'API token (meme nom que le DynaKube -> auto-detecte).
# - DynaKube en cloudNativeFullStack, scope au namespace easytrade via le label
#   integre kubernetes.io/metadata.name (pas d'annotation a poser).
# - Un rollout restart des pods easytrade (Etape 2) active l'injection.
# ==============================================================================

# --- Credentials depuis le Key Vault persistant -----------------------------

data "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_rg
}

data "azurerm_key_vault_secret" "api_url" {
  name         = "dynatrace-api-url"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "api_token" {
  name         = "dynatrace-api-token"
  key_vault_id = data.azurerm_key_vault.kv.id
}

# --- Namespace + secret de tokens -------------------------------------------

resource "kubernetes_namespace" "dynatrace" {
  metadata {
    name = var.namespace
  }
}

# Le secret doit porter le meme nom que le DynaKube pour etre auto-detecte.
resource "kubernetes_secret" "dynakube" {
  metadata {
    name      = "dynakube"
    namespace = kubernetes_namespace.dynatrace.metadata[0].name
  }

  data = {
    apiToken = data.azurerm_key_vault_secret.api_token.value
  }

  type = "Opaque"
}

# --- Operateur Dynatrace -----------------------------------------------------

resource "helm_release" "dynatrace_operator" {
  name      = "dynatrace-operator"
  chart     = "oci://public.ecr.aws/dynatrace/dynatrace-operator"
  version   = var.chart_version
  namespace = kubernetes_namespace.dynatrace.metadata[0].name

  atomic  = true
  timeout = 600

  set {
    name  = "installCRD"
    value = "true"
  }
}

# --- DynaKube (cloudNativeFullStack) ----------------------------------------

resource "kubectl_manifest" "dynakube" {
  yaml_body = yamlencode({
    apiVersion = var.dynakube_api_version
    kind       = "DynaKube"
    metadata = {
      name      = "dynakube"
      namespace = kubernetes_namespace.dynatrace.metadata[0].name
    }
    spec = {
      # L'URL du tenant est stockee sans /api dans le Key Vault.
      apiUrl = "${data.azurerm_key_vault_secret.api_url.value}/api"

      oneAgent = {
        cloudNativeFullStack = {
          # Injection limitee au namespace easytrade.
          namespaceSelector = {
            matchLabels = {
              "kubernetes.io/metadata.name" = var.easytrade_namespace
            }
          }
        }
      }

      activeGate = {
        capabilities = [
          "routing",
          "kubernetes-monitoring",
          "dynatrace-api",
        ]
      }
    }
  })

  depends_on = [
    helm_release.dynatrace_operator,
    kubernetes_secret.dynakube,
  ]
}
