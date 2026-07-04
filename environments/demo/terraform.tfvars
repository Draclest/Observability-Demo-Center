# ==============================================================================
# Variables du deploiement de demo
# Utilisation : terraform apply -var-file=environments/demo/terraform.tfvars
# ==============================================================================

# --- Souscription (renseigne par le bootstrap) ------------------------------
subscription_id = "a4ea47dc-5393-40e6-af33-f9693c503310"
location        = "westeurope"

# --- Key Vault persistant (renseigne par le bootstrap) ----------------------
# Remplacez <suffix> par la valeur affichee par le script de bootstrap.
key_vault_name = "kv-democenter-<suffix>"
key_vault_rg   = "rg-demo-center-infra"

# --- Plateforme d'observabilite : "splunk" | "dynatrace" | "elastic" --------
observability_platform = "splunk"

# --- Exposition publique ----------------------------------------------------
# Vide = ouvert a Internet. Renseignez des CIDR pour restreindre l'acces.
# Exemple : allowed_ip_ranges = ["203.0.113.10/32", "198.51.100.0/24"]
allowed_ip_ranges = []

# --- Application Easy Trade -------------------------------------------------
easytrade_loadgen_enabled          = true
easytrade_problem_patterns_enabled = true

# --- Garde-fous & couts -----------------------------------------------------
auto_destroy_ttl_hours = 8
budget_amount_eur      = 100
budget_contact_emails  = ["latour.geoffroy@gmail.com"]
