# ==============================================================================
# Outputs racine — recapitulatif de fin de deploiement
# ==============================================================================

# Instant de deploiement (capture une seule fois) -> base de la deadline.
resource "time_static" "deploy" {}

locals {
  auto_destroy_deadline = timeadd(time_static.deploy.rfc3339, "${var.auto_destroy_ttl_hours}h")

  kibana_url = try(module.observability_elastic[0].kibana_url, null)
}

output "observability_platform" {
  description = "Plateforme d'observabilite selectionnee."
  value       = var.observability_platform
}

output "deployment_step" {
  description = "Etape courante du deploiement."
  value       = var.deploy_observability_layer ? "2 — infra + application + observabilite" : "1 — infra + application (sans observabilite)"
}

output "location" {
  description = "Region Azure de la demo."
  value       = var.location
}

output "ingress_public_ip" {
  description = "IP publique statique de l'Ingress."
  value       = module.azure_infra.ingress_public_ip
}

output "easytrade_url" {
  description = "URL publique d'Easy Trade."
  value       = module.kubernetes_apps.url
}

output "kibana_url" {
  description = "URL publique de Kibana (Elastic, Etape 2 uniquement)."
  value       = local.kibana_url
}

output "deployment_time" {
  description = "Horodatage du deploiement (UTC)."
  value       = time_static.deploy.rfc3339
}

output "auto_destroy_deadline" {
  description = "Heure limite avant auto-destroy du RG (UTC)."
  value       = local.auto_destroy_deadline
}

output "estimated_cost_per_hour_eur" {
  description = "Cout horaire estime (indicatif)."
  value       = var.estimated_cost_per_hour_eur
}

output "reminder" {
  description = "Rappel des actions importantes."
  value       = <<-EOT

    ============================================================
     DEMO CENTER OBSERVABILITE — ${upper(var.observability_platform)}
    ============================================================
     Etape             : ${var.deploy_observability_layer ? "2 (observabilite active)" : "1 (application seule)"}
     Easy Trade        : ${module.kubernetes_apps.url}
     Kibana            : ${coalesce(local.kibana_url, "n/a (Splunk/Dynatrace : voir leur console)")}
     IP publique       : ${module.azure_infra.ingress_public_ip}

     Deploiement (UTC) : ${time_static.deploy.rfc3339}
     Auto-destroy avant: ${local.auto_destroy_deadline}
     Cout estime       : ~${var.estimated_cost_per_hour_eur} EUR / heure

    ${var.deploy_observability_layer ? "" : " >> Etape 2 : relancer avec -var 'deploy_observability_layer=true'"}
     >> NE PAS OUBLIER de detruire la demo apres usage :
        terraform destroy -var-file=environments/demo/terraform.tfvars
    ============================================================
  EOT
}
