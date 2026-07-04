# --- Resource group ---------------------------------------------------------

output "resource_group_name" {
  description = "Nom du resource group de la demo."
  value       = azurerm_resource_group.demo.name
}

output "resource_group_id" {
  description = "ID du resource group de la demo."
  value       = azurerm_resource_group.demo.id
}

output "location" {
  description = "Region Azure."
  value       = azurerm_resource_group.demo.location
}

# --- Cluster AKS ------------------------------------------------------------

output "cluster_name" {
  description = "Nom du cluster AKS."
  value       = azurerm_kubernetes_cluster.demo.name
}

output "node_resource_group" {
  description = "RG technique gere par AKS (noeuds, Load Balancers, disques)."
  value       = azurerm_kubernetes_cluster.demo.node_resource_group
}

# --- Acces Kubernetes (pour les providers kubernetes/helm/kubectl au root) ---

output "kube_host" {
  description = "Endpoint de l'API server AKS."
  value       = azurerm_kubernetes_cluster.demo.kube_admin_config[0].host
  sensitive   = true
}

output "kube_client_certificate" {
  value     = azurerm_kubernetes_cluster.demo.kube_admin_config[0].client_certificate
  sensitive = true
}

output "kube_client_key" {
  value     = azurerm_kubernetes_cluster.demo.kube_admin_config[0].client_key
  sensitive = true
}

output "kube_cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.demo.kube_admin_config[0].cluster_ca_certificate
  sensitive = true
}

output "kube_config_raw" {
  description = "Kubeconfig complet (admin) — utile pour les local-exec kubectl."
  value       = azurerm_kubernetes_cluster.demo.kube_admin_config_raw
  sensitive   = true
}

# --- Ingress ----------------------------------------------------------------

output "ingress_namespace" {
  description = "Namespace de l'Ingress Controller NGINX."
  value       = helm_release.ingress_nginx.namespace
}

output "ingress_class_name" {
  description = "IngressClass a utiliser dans les ressources Ingress."
  value       = "nginx"
}

output "cluster_issuer_name" {
  description = "ClusterIssuer cert-manager pour le TLS auto-signe."
  value       = "selfsigned-issuer"
}
