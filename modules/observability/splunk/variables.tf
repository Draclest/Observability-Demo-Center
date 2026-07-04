variable "cluster_name" {
  type        = string
  description = "Nom du cluster AKS (attribut clusterName envoye a Splunk)."
}

variable "collector_namespace" {
  type        = string
  description = "Namespace du Splunk OTel Collector et de l'OTel Operator."
  default     = "splunk-otel"
}

variable "chart_version" {
  type        = string
  description = "Version du chart splunk-otel-collector."
  default     = "0.129.0"
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault persistant contenant les credentials Splunk."
}

variable "key_vault_rg" {
  type        = string
  description = "Resource group du Key Vault persistant."
}
