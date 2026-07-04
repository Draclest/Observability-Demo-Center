# --- Identite & localisation ------------------------------------------------

variable "subscription_id" {
  type        = string
  description = "ID de la souscription (utilise par le runbook d'auto-destroy)."
}

variable "location" {
  type        = string
  description = "Region Azure."
}

variable "resource_group_name" {
  type        = string
  description = "Nom du resource group de la demo."
}

variable "prefix" {
  type        = string
  description = "Prefixe des noms de ressources."
}

variable "common_tags" {
  type        = map(string)
  description = "Tags communs."
  default     = {}
}

# --- AKS --------------------------------------------------------------------

variable "kubernetes_version" {
  type        = string
  description = "Version Kubernetes (null = derniere stable)."
  default     = null
}

variable "sku_system" {
  type        = string
  description = "SKU du pool system."
}

variable "sku_easytrade" {
  type        = string
  description = "SKU du pool easytrade."
}

variable "sku_observability" {
  type        = string
  description = "SKU du pool observability (Elastic)."
}

variable "observability_node_count" {
  type        = number
  description = "Nombre de noeuds du pool observability."
}

variable "is_elastic" {
  type        = bool
  description = "Vrai si la plateforme est Elastic (=> pool observability dedie)."
}

# --- Exposition publique ----------------------------------------------------

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "CIDR autorises sur le LoadBalancer de l'Ingress. Vide = ouvert."
  default     = []
}

# --- Garde-fous -------------------------------------------------------------

variable "auto_destroy_ttl_hours" {
  type        = number
  description = "Delai avant auto-destroy du RG (heures)."
}

variable "budget_amount_eur" {
  type        = number
  description = "Budget mensuel (EUR) pour l'alerte de cout."
}

variable "budget_contact_emails" {
  type        = list(string)
  description = "Emails destinataires des alertes de budget."
}
