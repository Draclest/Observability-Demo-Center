# ==============================================================================
# Exposition publique de Kibana : certificat TLS auto-signe + Ingress
# (Elasticsearch reste interne au cluster — non expose.)
# ==============================================================================

resource "kubectl_manifest" "kibana_certificate" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: kibana-tls
      namespace: ${kubernetes_namespace.elastic.metadata[0].name}
    spec:
      secretName: kibana-tls
      dnsNames:
        - ${var.kibana_hostname}
      issuerRef:
        name: ${var.cluster_issuer_name}
        kind: ClusterIssuer
  YAML
}

resource "kubernetes_ingress_v1" "kibana" {
  metadata {
    name      = "kibana"
    namespace = kubernetes_namespace.elastic.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name

    tls {
      hosts       = [var.kibana_hostname]
      secret_name = "kibana-tls"
    }

    rule {
      host = var.kibana_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              # TLS HTTP de Kibana desactive -> backend HTTP sur 5601.
              name = "kibana-kb-http"
              port {
                number = 5601
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubectl_manifest.kibana,
    kubectl_manifest.kibana_certificate,
  ]
}
