# ==============================================================================
# Variables racine — Demo Center Observabilite
# ==============================================================================

# --- Souscription & region --------------------------------------------------

variable "subscription_id" {
  type        = string
  description = "ID de la souscription Azure cible (l'authentification se fait via `az login`)."
}

variable "location" {
  type        = string
  description = "Region Azure de deploiement de la demo."
  default     = "westeurope"
}

variable "resource_group_name" {
  type        = string
  description = "Nom du resource group de la demo (cree et detruit par ce projet)."
  default     = "rg-demo-observabilite"
}

variable "prefix" {
  type        = string
  description = "Prefixe court applique aux noms de ressources Azure."
  default     = "democenter"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.prefix))
    error_message = "prefix doit faire 3 a 12 caracteres minuscules alphanumeriques."
  }
}

# --- Selection de la plateforme d'observabilite -----------------------------

variable "observability_platform" {
  type        = string
  description = "Plateforme d'observabilite a deployer : splunk, dynatrace ou elastic."

  validation {
    condition     = contains(["splunk", "dynatrace", "elastic"], var.observability_platform)
    error_message = "observability_platform doit valoir 'splunk', 'dynatrace' ou 'elastic'."
  }
}

# --- Key Vault persistant (credentials Splunk / Dynatrace) ------------------

variable "key_vault_name" {
  type        = string
  description = "Nom du Key Vault persistant contenant les credentials Splunk/Dynatrace."
}

variable "key_vault_rg" {
  type        = string
  description = "Resource group du Key Vault persistant (hors perimetre de la demo)."
  default     = "rg-demo-center-infra"
}

# --- Dimensionnement AKS ----------------------------------------------------

variable "kubernetes_version" {
  type        = string
  description = "Version de Kubernetes pour AKS. null = derniere version stable supportee par la region."
  default     = null
}

variable "sku_system" {
  type        = string
  description = "SKU des noeuds du pool system."
  default     = "Standard_D2s_v5"
}

variable "sku_easytrade" {
  type        = string
  description = "SKU des noeuds du pool easytrade."
  default     = "Standard_D4s_v5"
}

variable "sku_observability" {
  type        = string
  description = "SKU des noeuds du pool observability (Elastic uniquement)."
  default     = "Standard_D4s_v5"
}

variable "observability_node_count" {
  type        = number
  description = "Nombre de noeuds du pool observability (Elastic uniquement)."
  default     = 2
}

# --- Exposition publique & securite -----------------------------------------

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "Liste de CIDR autorises sur les Ingress publics. Vide = ouvert a Internet."
  default     = []
}

# --- Application Easy Trade --------------------------------------------------

variable "easytrade_loadgen_enabled" {
  type        = bool
  description = "Active le generateur de charge d'Easy Trade."
  default     = true
}

variable "easytrade_problem_patterns_enabled" {
  type        = bool
  description = "Active les problem patterns d'Easy Trade (simulation d'anomalies)."
  default     = true
}

# --- Garde-fous & couts -----------------------------------------------------

variable "auto_destroy_ttl_hours" {
  type        = number
  description = "Delai (heures) apres lequel le runbook auto-destroy supprime le RG de la demo."
  default     = 8

  validation {
    condition     = var.auto_destroy_ttl_hours >= 1 && var.auto_destroy_ttl_hours <= 72
    error_message = "auto_destroy_ttl_hours doit etre compris entre 1 et 72."
  }
}

variable "budget_amount_eur" {
  type        = number
  description = "Budget mensuel Azure (EUR) sur le RG de la demo, pour l'alerte de cout."
  default     = 100
}

variable "budget_contact_emails" {
  type        = list(string)
  description = "Adresses email destinataires des alertes de budget."
  default     = []
}

variable "estimated_cost_per_hour_eur" {
  type        = number
  description = "Cout horaire estime affiche en output (indicatif, pour rappel de destruction)."
  default     = 3.5
}

# --- Divers -----------------------------------------------------------------

variable "tags" {
  type        = map(string)
  description = "Tags additionnels appliques aux ressources de la demo."
  default     = {}
}
