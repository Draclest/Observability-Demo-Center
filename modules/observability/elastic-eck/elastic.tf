# ==============================================================================
# Elasticsearch + Kibana (ressources CRD ECK)
#
# Note : on deploie les ressources Elasticsearch/Kibana directement via leurs
# CRD ECK (fonctionnellement equivalent au chart eck-stack, mais schema plus
# previsible). TLS HTTP interne desactive pour simplifier l'Ingress Kibana
# (terminaison TLS assuree par NGINX) et la connexion EDOT -> Elasticsearch.
# ==============================================================================

locals {
  # nodeSelector + toleration communs pour epingler ECK au pool observability.
  observability_scheduling = {
    nodeSelector = {
      workload = var.node_pool_label
    }
    tolerations = [{
      key      = "workload"
      operator = "Equal"
      value    = var.node_pool_label
      effect   = "NoSchedule"
    }]
  }
}

resource "kubectl_manifest" "elasticsearch" {
  yaml_body = yamlencode({
    apiVersion = "elasticsearch.k8s.elastic.co/v1"
    kind       = "Elasticsearch"
    metadata = {
      name      = "elasticsearch"
      namespace = kubernetes_namespace.elastic.metadata[0].name
    }
    spec = {
      version = var.elastic_version
      nodeSets = [{
        name  = "default"
        count = var.es_node_count
        config = {
          "node.store.allow_mmap" = false
        }
        podTemplate = {
          spec = local.observability_scheduling
        }
        volumeClaimTemplates = [{
          metadata = {
            name = "elasticsearch-data"
          }
          spec = {
            accessModes = ["ReadWriteOnce"]
            resources = {
              requests = {
                storage = var.es_storage_size
              }
            }
            storageClassName = var.storage_class_name
          }
        }]
      }]
      http = {
        tls = {
          selfSignedCertificate = {
            disabled = true
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.eck_operator,
    kubernetes_storage_class_v1.elasticsearch,
  ]
}

resource "kubectl_manifest" "kibana" {
  yaml_body = yamlencode({
    apiVersion = "kibana.k8s.elastic.co/v1"
    kind       = "Kibana"
    metadata = {
      name      = "kibana"
      namespace = kubernetes_namespace.elastic.metadata[0].name
    }
    spec = {
      version = var.elastic_version
      count   = 1
      elasticsearchRef = {
        name = "elasticsearch"
      }
      podTemplate = {
        spec = local.observability_scheduling
      }
      http = {
        tls = {
          selfSignedCertificate = {
            disabled = true
          }
        }
      }
    }
  })

  depends_on = [kubectl_manifest.elasticsearch]
}
