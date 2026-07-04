output "instrumentation_reference" {
  description = "Reference <namespace>/<name> de l'Instrumentation OTel creee par le chart."
  value       = "${kubernetes_namespace.splunk.metadata[0].name}/splunk-otel-collector"
}

output "ready_token" {
  description = "Jeton de disponibilite (change quand la couche est deployee) — declencheur du rollout restart."
  value       = helm_release.splunk_otel.id
}

output "kibana_url" {
  description = "Non applicable pour Splunk (destination externe)."
  value       = null
}
