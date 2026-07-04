# ==============================================================================
# Rollout restart (Etape 2) et nettoyage ordonne a la destruction
#
# Ces operations s'appuient sur kubectl (prerequis) et un kubeconfig ecrit sur
# disque a partir des identifiants admin de l'AKS.
# ==============================================================================

locals {
  kubeconfig_path = "${path.root}/.kube/demo-kubeconfig"

  # Jeton de disponibilite de la couche d'observabilite active (declencheur du
  # rollout restart). "none" tant que l'Etape 2 n'est pas deployee.
  obs_ready = coalesce(
    try(module.observability_splunk[0].ready_token, ""),
    try(module.observability_dynatrace[0].ready_token, ""),
    try(module.observability_elastic[0].ready_token, ""),
    "none",
  )
}

# Kubeconfig admin ecrit localement (ignore par git ; permissions restreintes).
resource "local_file" "kubeconfig" {
  content         = module.azure_infra.kube_config_raw
  filename        = local.kubeconfig_path
  file_permission = "0600"
}

# --- Rollout restart d'Easy Trade (Etape 2) ---------------------------------
# Redemarre les deployments pour que l'injection d'instrumentation prenne effet
# ("on redemarre et les traces apparaissent"). N'existe qu'a l'Etape 2.
resource "null_resource" "rollout_restart" {
  count = local.deploy_obs ? 1 : 0

  triggers = {
    obs_ready = local.obs_ready
  }

  provisioner "local-exec" {
    command = "kubectl --kubeconfig \"${local.kubeconfig_path}\" rollout restart deployment --namespace ${module.kubernetes_apps.namespace}"
  }

  depends_on = [
    local_file.kubeconfig,
    module.observability_splunk,
    module.observability_dynatrace,
    module.observability_elastic,
  ]
}

# --- Nettoyage des Load Balancers avant destruction du cluster --------------
# Supprime le Service LoadBalancer de l'Ingress (et attend la suppression de l'IP
# cote Azure) AVANT que l'AKS ne soit detruit, pour eviter tout LB orphelin.
resource "null_resource" "lb_cleanup" {
  triggers = {
    kubeconfig = local.kubeconfig_path
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "kubectl --kubeconfig \"${self.triggers.kubeconfig}\" delete svc --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found --wait=true"
  }

  depends_on = [
    local_file.kubeconfig,
    module.azure_infra,
    module.kubernetes_apps,
  ]
}

# --- Nettoyage des PVC Elasticsearch avant destruction (Elastic uniquement) --
# Garantit la suppression des PVC (et donc des Azure Disks via reclaimPolicy
# Delete) avant la destruction des ressources Kubernetes.
resource "null_resource" "pvc_cleanup" {
  count = local.is_elastic ? 1 : 0

  triggers = {
    kubeconfig = local.kubeconfig_path
    namespace  = local.elastic_namespace
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "kubectl --kubeconfig \"${self.triggers.kubeconfig}\" delete pvc --all --namespace ${self.triggers.namespace} --ignore-not-found --wait=true"
  }

  depends_on = [
    local_file.kubeconfig,
    module.azure_infra,
  ]
}
