# Description des modules Terraform

## `modules/azure-infra`

Infrastructure Azure de la démo.

**Rôle :** resource group, réseau (VNet/subnet), cluster AKS avec node pools
conditionnels, Ingress Controller NGINX, cert-manager + ClusterIssuer auto-signé,
IP publique statique, alerte de budget, mécanisme d'auto-destroy.

**Entrées clés :** `subscription_id`, `location`, `resource_group_name`, `prefix`,
`sku_system` / `sku_easytrade` / `sku_observability`, `observability_node_count`,
`is_elastic` (ajoute le pool observability), `allowed_ip_ranges`,
`auto_destroy_ttl_hours`, `budget_amount_eur`, `budget_contact_emails`,
`common_tags`.

**Sorties clés :** `resource_group_name`, `cluster_name`, `node_resource_group`,
`kube_host` / `kube_client_certificate` / `kube_client_key` /
`kube_cluster_ca_certificate` / `kube_config_raw` (identifiants AKS pour les
providers et kubectl), `ingress_class_name`, `cluster_issuer_name`,
`ingress_public_ip`.

**Points notables :**
- Pool `system` taggé `only_critical_addons_enabled` (taint CriticalAddonsOnly)
  → Easy Trade se planifie sur le pool `easytrade`.
- Pool `observability` (Elastic) avec taint `workload=observability:NoSchedule`
  réservé à ECK.
- Auto-destroy : Automation Account + runbook PowerShell (appel REST via identité
  managée, sans dépendance de module) planifié à `deploy + TTL`.

## `modules/kubernetes-apps`

Application Easy Trade.

**Rôle :** namespace `easytrade`, `helm_release` du chart OCI Easy Trade
(load generator + problem patterns activables), certificat TLS auto-signé et
Ingress routé par hostname.

**Entrées clés :** `namespace`, `chart_version`, `loadgen_enabled`,
`problem_patterns_enabled`, `instrumentation_annotations` (posées à l'Étape 2),
`ingress_class_name`, `cluster_issuer_name`, `hostname`.

**Sorties clés :** `namespace`, `release_name`, `frontend_service_name`,
`ingress_name`, `url`.

## `modules/observability/splunk`

**Rôle :** Splunk Distribution of OpenTelemetry Collector (DaemonSet) + OTel
Operator upstream (auto-instrumentation zero-code). Destination : Splunk
Observability Cloud.

**Entrées clés :** `cluster_name`, `collector_namespace`, `chart_version`,
`key_vault_name`, `key_vault_rg`.

**Sorties :** `instrumentation_reference` (`<ns>/splunk-otel-collector`),
`ready_token` (déclencheur du rollout restart).

## `modules/observability/dynatrace`

**Rôle :** Dynatrace Operator en `cloudNativeFullStack` (injection par pod).
DynaKube scopé au namespace `easytrade` via le label `kubernetes.io/metadata.name`.

**Entrées clés :** `easytrade_namespace`, `chart_version`, `dynakube_api_version`,
`key_vault_name`, `key_vault_rg`.

**Sorties :** `ready_token`. (Pas d'annotation OTel : injection par webhook.)

## `modules/observability/elastic-eck`

**Rôle :** opérateur ECK, Elasticsearch (2 nœuds sur le pool observability),
Kibana (exposé), EDOT via `opentelemetry-kube-stack`, StorageClass
`reclaimPolicy: Delete`, Ingress Kibana.

**Entrées clés :** `namespace`, `easytrade_namespace`, `elastic_version`,
`eck_operator_version`, `otel_kube_stack_version`, `es_node_count`,
`es_storage_size`, `storage_class_name`, `node_pool_label`, `ingress_class_name`,
`cluster_issuer_name`, `kibana_hostname`.

**Sorties :** `instrumentation_reference`, `ready_token`, `kibana_url`.

**Points notables :**
- TLS HTTP interne d'Elasticsearch/Kibana désactivé (terminaison TLS par NGINX,
  connexion EDOT → ES en HTTP interne).
- EDOT lit le mot de passe `elastic` directement depuis le secret généré par ECK
  (`elasticsearch-es-elastic-user`) via `secretKeyRef` — pas de lecture Terraform
  (évite toute course à la création du secret).

## Assemblage racine

- `main.tf` : locals conditionnels (plateforme, annotations OTel statiques,
  hostnames nip.io), instanciation des modules (observabilité en `count` selon la
  plateforme et `deploy_observability_layer`).
- `cleanup.tf` : `local_file` kubeconfig, rollout restart (Étape 2), nettoyage
  destroy-time des LoadBalancers et des PVC Elasticsearch.
- `outputs.tf` : URLs, horodatage, deadline auto-destroy, coût estimé, rappel.
