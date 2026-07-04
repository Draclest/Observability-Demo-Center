output "instrumentation_reference" {
  description = "Non applicable pour Dynatrace (injection par webhook cloudNativeFullStack, pas d'annotation OTel)."
  value       = null
}

output "ready_token" {
  description = "Jeton de disponibilite — declencheur du rollout restart."
  value       = kubectl_manifest.dynakube.id
}

output "kibana_url" {
  description = "Non applicable pour Dynatrace (destination externe)."
  value       = null
}
