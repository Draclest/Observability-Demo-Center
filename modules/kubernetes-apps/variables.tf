variable "namespace" {
  type        = string
  description = "Namespace Kubernetes d'Easy Trade."
  default     = "easytrade"
}

variable "release_name" {
  type        = string
  description = "Nom de la release Helm Easy Trade."
  default     = "easytrade"
}

variable "chart_version" {
  type        = string
  description = "Version du chart Helm Easy Trade (OCI)."
  default     = "1.5.3"
}

variable "loadgen_enabled" {
  type        = bool
  description = "Active le generateur de charge (loadgen)."
  default     = true
}

variable "problem_patterns_enabled" {
  type        = bool
  description = "Active les problem patterns (problem-operator)."
  default     = true
}

variable "instrumentation_annotations" {
  type        = map(string)
  description = "Annotations d'auto-instrumentation OTel appliquees au namespace (Etape 2)."
  default     = {}
}

variable "ingress_class_name" {
  type        = string
  description = "IngressClass a utiliser (ex. nginx)."
}

variable "cluster_issuer_name" {
  type        = string
  description = "ClusterIssuer cert-manager pour le certificat TLS auto-signe."
}

variable "hostname" {
  type        = string
  description = "Hostname public d'Easy Trade (ex. easytrade.<ip>.nip.io)."
}
