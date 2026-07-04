variable "easytrade_namespace" {
  type        = string
  description = "Namespace d'Easy Trade a instrumenter (namespaceSelector du DynaKube)."
}

variable "namespace" {
  type        = string
  description = "Namespace de l'operateur Dynatrace."
  default     = "dynatrace"
}

variable "chart_version" {
  type        = string
  description = "Version du chart dynatrace-operator (OCI)."
  default     = "1.3.2"
}

variable "dynakube_api_version" {
  type        = string
  description = "Version d'API de la CRD DynaKube (a verifier selon la version de l'operateur)."
  default     = "dynatrace.com/v1beta3"
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault persistant contenant les credentials Dynatrace."
}

variable "key_vault_rg" {
  type        = string
  description = "Resource group du Key Vault persistant."
}
