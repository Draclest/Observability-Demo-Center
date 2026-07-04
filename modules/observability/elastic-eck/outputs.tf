output "instrumentation_reference" {
  description = "Reference <namespace>/<name> de l'Instrumentation EDOT (creee par opentelemetry-kube-stack)."
  # opentelemetry-kube-stack cree une Instrumentation portant le nom de la release.
  value = "${kubernetes_namespace.elastic.metadata[0].name}/opentelemetry-kube-stack"
}

output "ready_token" {
  description = "Jeton de disponibilite — declencheur du rollout restart."
  value       = helm_release.edot.id
}

output "kibana_ingress_name" {
  description = "Nom de la ressource Ingress de Kibana."
  value       = kubernetes_ingress_v1.kibana.metadata[0].name
}

output "kibana_url" {
  description = "URL publique de Kibana."
  value       = "https://${var.kibana_hostname}"
}
