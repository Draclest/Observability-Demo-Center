# Provider azurerm : authentification via `az login` (aucun secret stocke).
provider "azurerm" {
  subscription_id = var.subscription_id

  features {
    resource_group {
      # Securite : empeche un destroy si des ressources hors state subsistent
      # dans le RG (ex. Load Balancer orphelin). Force un nettoyage correct.
      prevent_deletion_if_contains_resources = true
    }

    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

# ------------------------------------------------------------------------------
# Providers kubernetes / helm / kubectl configures a partir des sorties du module
# azure-infra (identifiants admin de l'AKS). Terraform evalue ces configurations
# apres la creation du cluster (les ressources k8s en dependent), ce qui resout
# l'ordonnancement infra -> charges applicatives.
# ------------------------------------------------------------------------------

provider "kubernetes" {
  host                   = module.azure_infra.kube_host
  client_certificate     = base64decode(module.azure_infra.kube_client_certificate)
  client_key             = base64decode(module.azure_infra.kube_client_key)
  cluster_ca_certificate = base64decode(module.azure_infra.kube_cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.azure_infra.kube_host
    client_certificate     = base64decode(module.azure_infra.kube_client_certificate)
    client_key             = base64decode(module.azure_infra.kube_client_key)
    cluster_ca_certificate = base64decode(module.azure_infra.kube_cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = module.azure_infra.kube_host
  client_certificate     = base64decode(module.azure_infra.kube_client_certificate)
  client_key             = base64decode(module.azure_infra.kube_client_key)
  cluster_ca_certificate = base64decode(module.azure_infra.kube_cluster_ca_certificate)
  load_config_file       = false
}
