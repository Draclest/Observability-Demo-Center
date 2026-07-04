output "namespace" {
  description = "Namespace d'Easy Trade."
  value       = kubernetes_namespace.easytrade.metadata[0].name
}

output "release_name" {
  description = "Nom de la release Helm Easy Trade."
  value       = helm_release.easytrade.name
}

output "frontend_service_name" {
  description = "Service reverse proxy frontal (point d'entree HTTP)."
  value       = "${var.release_name}-frontendreverseproxy"
}

output "ingress_name" {
  description = "Nom de la ressource Ingress d'Easy Trade."
  value       = kubernetes_ingress_v1.easytrade.metadata[0].name
}

output "url" {
  description = "URL publique d'Easy Trade."
  value       = "https://${var.hostname}"
}
