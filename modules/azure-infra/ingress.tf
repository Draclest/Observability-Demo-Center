# ==============================================================================
# Ingress Controller (NGINX) + cert-manager (TLS auto-signe)
# ==============================================================================

# --- NGINX Ingress Controller -----------------------------------------------
# Service de type LoadBalancer -> provisionne une IP publique Azure.
# L'allowlist d'IP (si fournie) est appliquee au niveau du Load Balancer via
# loadBalancerSourceRanges.

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3"
  namespace        = "ingress-nginx"
  create_namespace = true
  atomic           = true
  timeout          = 600

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Sonde de sante Azure LB sur le endpoint healthz de NGINX.
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  # Allowlist d'IP (optionnelle) : liste de CIDR autorises sur le LB.
  dynamic "set_list" {
    for_each = length(var.allowed_ip_ranges) > 0 ? [1] : []
    content {
      name  = "controller.service.loadBalancerSourceRanges"
      value = var.allowed_ip_ranges
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster_node_pool.easytrade,
  ]
}

# --- cert-manager -----------------------------------------------------------

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.16.2"
  namespace        = "cert-manager"
  create_namespace = true
  atomic           = true
  timeout          = 600

  set {
    name  = "crds.enabled"
    value = "true"
  }

  depends_on = [
    azurerm_kubernetes_cluster_node_pool.easytrade,
  ]
}

# --- ClusterIssuer auto-signe -----------------------------------------------
# Emet des certificats self-signed pour les Ingress publics (avertissement
# navigateur attendu — adapte a une demo de quelques heures).

resource "kubectl_manifest" "selfsigned_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: selfsigned-issuer
    spec:
      selfSigned: {}
  YAML

  depends_on = [helm_release.cert_manager]
}
