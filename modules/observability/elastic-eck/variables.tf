variable "namespace" {
  type        = string
  description = "Namespace de la stack Elastic (ECK)."
  default     = "elastic-stack"
}

variable "easytrade_namespace" {
  type        = string
  description = "Namespace d'Easy Trade a instrumenter."
}

variable "elastic_version" {
  type        = string
  description = "Version d'Elasticsearch / Kibana."
  default     = "8.15.3"
}

variable "eck_operator_version" {
  type        = string
  description = "Version du chart eck-operator."
  default     = "2.14.0"
}

variable "otel_kube_stack_version" {
  type        = string
  description = "Version du chart opentelemetry-kube-stack (EDOT)."
  default     = "0.3.9"
}

variable "es_node_count" {
  type        = number
  description = "Nombre de noeuds Elasticsearch."
  default     = 2
}

variable "es_storage_size" {
  type        = string
  description = "Taille du volume par noeud Elasticsearch."
  default     = "20Gi"
}

variable "storage_class_name" {
  type        = string
  description = "Nom de la StorageClass (reclaimPolicy Delete) des PVC Elasticsearch."
  default     = "elasticsearch-sc"
}

variable "node_pool_label" {
  type        = string
  description = "Valeur du label workload identifiant le pool observability."
  default     = "observability"
}

variable "ingress_class_name" {
  type        = string
  description = "IngressClass pour l'exposition de Kibana."
}

variable "cluster_issuer_name" {
  type        = string
  description = "ClusterIssuer cert-manager pour le TLS auto-signe de Kibana."
}

variable "kibana_hostname" {
  type        = string
  description = "Hostname public de Kibana (ex. kibana.<ip>.nip.io)."
}
