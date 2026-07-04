# ==============================================================================
# Elastic (ECK) : operateur ECK + StorageClass dediee
#
# Le pool observability (taint workload=observability) est reserve a ECK :
# Elasticsearch et Kibana portent le nodeSelector + toleration correspondants.
# ==============================================================================

resource "kubernetes_namespace" "elastic" {
  metadata {
    name = var.namespace
  }
}

# StorageClass dediee aux PVC Elasticsearch, avec reclaimPolicy Delete : les
# Azure Disks sous-jacents sont supprimes avec les PVC (nettoyage complet).
resource "kubernetes_storage_class_v1" "elasticsearch" {
  metadata {
    name = var.storage_class_name
  }
  storage_provisioner    = "disk.csi.azure.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    skuname = "Premium_LRS"
  }
}

# --- Operateur ECK ----------------------------------------------------------

resource "helm_release" "eck_operator" {
  name       = "eck-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = var.eck_operator_version
  namespace  = kubernetes_namespace.elastic.metadata[0].name

  atomic  = true
  timeout = 600
}
