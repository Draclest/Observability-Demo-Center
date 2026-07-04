# ==============================================================================
# Exposition publique d'Easy Trade : certificat TLS auto-signe + Ingress
# ==============================================================================

# Certificat auto-signe emis par le ClusterIssuer cert-manager pour le hostname
# public (nip.io). Un avertissement navigateur (CA self-signed) reste attendu et
# acceptable pour une demo courte.
resource "kubectl_manifest" "easytrade_certificate" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: easytrade-tls
      namespace: ${kubernetes_namespace.easytrade.metadata[0].name}
    spec:
      secretName: easytrade-tls
      dnsNames:
        - ${var.hostname}
      issuerRef:
        name: ${var.cluster_issuer_name}
        kind: ClusterIssuer
  YAML
}

# Ingress route par host vers le reverse proxy frontal d'Easy Trade. Redirection
# HTTPS forcee.
resource "kubernetes_ingress_v1" "easytrade" {
  metadata {
    name      = "easytrade"
    namespace = kubernetes_namespace.easytrade.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name

    tls {
      hosts       = [var.hostname]
      secret_name = "easytrade-tls"
    }

    rule {
      host = var.hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "${var.release_name}-frontendreverseproxy"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.easytrade,
    kubectl_manifest.easytrade_certificate,
  ]
}
