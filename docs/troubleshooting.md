# Dépannage & checklist de destruction

## Cas courants

### Pods en `Pending`
- **Cause fréquente** : capacité insuffisante ou taint/toleration.
  - Easy Trade ne se planifie pas sur le pool `system` (taint CriticalAddonsOnly)
    → vérifier que le pool `easytrade` est `Ready` : `kubectl get nodes -L workload`.
  - ECK (Elastic) exige le pool `observability` : vérifier son existence et le
    taint `workload=observability:NoSchedule`.
- **Ressources** : ajuster les SKU/nombres de nœuds (`sku_*`,
  `observability_node_count`) — les tailles du cadrage sont un point de départ.

### Instrumentation non active (aucune trace)
1. Vérifier que l'**Étape 2** a bien été appliquée
   (`-var 'deploy_observability_layer=true'`).
2. Vérifier le **rollout restart** : `kubectl -n easytrade rollout status deploy`.
   Relancer si besoin : `kubectl -n easytrade rollout restart deployment`.
3. **Splunk / Elastic** : vérifier les annotations du namespace
   `kubectl get ns easytrade -o yaml` et l'existence de la ressource
   `Instrumentation` (`kubectl get instrumentation -A`). La langue injectée doit
   correspondre au service (par défaut : java, dotnet, nodejs — voir
   `local.otel_languages`).
4. **Dynatrace** : vérifier le DynaKube (`kubectl -n dynatrace get dynakube`) et
   que le webhook est prêt. L'injection ne concerne que le namespace `easytrade`.

### EDOT / `opentelemetry-kube-stack` échoue au déploiement
Le schéma de values de ce chart évolue selon la version. Comparer avec :
```bash
helm show values open-telemetry/opentelemetry-kube-stack --version <ver>
```
Points à vérifier : structure `collectors.<name>.config`, presets disponibles,
clé de l'exporter `elasticsearch`, endpoint OTLP de l'`instrumentation`. La
version est pilotée par `otel_kube_stack_version`.

### CRD `DynaKube` refusée (version d'API)
La version d'API de la CRD dépend de la version de l'opérateur Dynatrace. Ajuster
`dynakube_api_version` (défaut `dynatrace.com/v1beta3`) et `chart_version`.

### IP publique non attachée à l'Ingress
L'identité du cluster AKS doit avoir `Network Contributor` sur l'IP (géré par
`azurerm_role_assignment.aks_ingress_ip`). Si l'attribution vient d'être créée,
un délai de propagation peut nécessiter un second `apply`.

### Certificat non émis (Ingress en 404/TLS par défaut)
Vérifier cert-manager : `kubectl get certificate,clusterissuer -A`. Le
ClusterIssuer `selfsigned-issuer` doit être `Ready`. Un avertissement navigateur
(CA auto-signée) est **normal**.

### Accès refusé au Key Vault pendant `apply`
L'utilisateur `az login` doit avoir `secrets get/list` sur le Key Vault (voir
[`credentials.md`](credentials.md)).

## Checklist de destruction complète

```bash
terraform destroy -var-file=environments/demo/terraform.tfvars \
  -var 'deploy_observability_layer=true'
```

Puis vérifier qu'il ne reste **rien** :

```bash
# Le RG de la démo doit être vide ou supprimé
az resource list --resource-group rg-demo-observabilite -o table

# Aucun disque managé résiduel
az disk list --resource-group rg-demo-observabilite -o table

# Aucune IP publique orpheline
az network public-ip list --resource-group rg-demo-observabilite -o table

# Le RG technique AKS ne doit plus exister
az group show --name rg-demo-observabilite-aks-nodes 2>/dev/null || echo "supprimé (OK)"
```

Le nettoyage ordonné (LoadBalancers puis PVC Elasticsearch avant le cluster) est
automatisé dans [`cleanup.tf`](../cleanup.tf). Si un LoadBalancer subsiste malgré
tout, le supprimer côté Kubernetes puis relancer `terraform destroy` :

```bash
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer
```

> **Key Vault et Storage Account persistants** (RG `rg-demo-center-infra`) ne sont
> **jamais** détruits — c'est volontaire (coût < 1 $/mois, évite de re-saisir les
> credentials et de reconfigurer le backend).

## Auto-destroy programmé

Un Automation Account (dans le RG de la démo) supprime le RG après
`auto_destroy_ttl_hours` (défaut 8 h). Il disparaît proprement lors d'un
`terraform destroy` manuel. Pour vérifier / ajuster la planification :

```bash
az automation schedule list \
  --resource-group rg-demo-observabilite \
  --automation-account-name democenter-autodestroy -o table
```
