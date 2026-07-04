# ==============================================================================
# Outputs racine
#
# Les URLs publiques (Easy Trade, Kibana) et le recapitulatif de fin de
# deploiement (heure, cout horaire, rappel de destroy) sont ajoutes en Phase 4,
# une fois les modules cables.
# ==============================================================================

output "observability_platform" {
  description = "Plateforme d'observabilite deployee."
  value       = var.observability_platform
}

output "location" {
  description = "Region Azure de la demo."
  value       = var.location
}
