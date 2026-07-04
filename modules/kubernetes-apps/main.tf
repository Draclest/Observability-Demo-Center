# ==============================================================================
# Easy Trade (chart Helm officiel Dynatrace, registre OCI)
# ==============================================================================

# Namespace dedie. Les annotations d'auto-instrumentation OTel (Etape 2) sont
# passees en entree : elles sont inertes tant que l'Operator/Instrumentation de
# la plateforme n'est pas deploye, et ne prennent effet qu'au rollout restart.
resource "kubernetes_namespace" "easytrade" {
  metadata {
    name        = var.namespace
    annotations = var.instrumentation_annotations
  }
}

# Easy Trade : chart OCI. Le generateur de charge (loadgen) et les problem
# patterns (problem-operator) sont essentiels en demo d'observabilite.
resource "helm_release" "easytrade" {
  name      = var.release_name
  chart     = "oci://europe-docker.pkg.dev/dynatrace-demoability/helm/easytrade"
  version   = var.chart_version
  namespace = kubernetes_namespace.easytrade.metadata[0].name

  atomic  = true
  timeout = 900

  set {
    name  = "loadgen.enabled"
    value = tostring(var.loadgen_enabled)
  }

  set {
    name  = "problem-operator.enabled"
    value = tostring(var.problem_patterns_enabled)
  }
}
