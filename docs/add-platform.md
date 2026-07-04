# Ajouter une nouvelle plateforme d'observabilité

Le projet est conçu pour accueillir de nouvelles plateformes sans refonte. Exemple
fictif : ajouter **Datadog**.

## 1. Créer le sous-module

```
modules/observability/datadog/
├── versions.tf     # providers requis (azurerm si Key Vault, helm, kubernetes, kubectl)
├── variables.tf    # entrées (namespace, key_vault_*, easytrade_namespace, hostnames…)
├── main.tf         # data KV + helm_release de l'agent/opérateur + CRs éventuels
└── outputs.tf      # instrumentation_reference, ready_token, (kibana_url = null)
```

Respectez le **contrat de sortie commun** attendu par la racine :

| Output | Rôle |
|---|---|
| `instrumentation_reference` | `<ns>/<instrumentation>` ou `null` si injection non-OTel |
| `ready_token` | Valeur qui change quand la couche est prête (déclenche le rollout restart) |
| `kibana_url` *(si UI exposée)* | URL publique, sinon `null` |

## 2. Enregistrer les credentials (si nécessaire)

Ajouter les secrets dans le Key Vault persistant et documenter leur nom
(voir [`credentials.md`](credentials.md)). Ajouter éventuellement leur seeding au
script `bootstrap/bootstrap.ps1`.

## 3. Câbler la racine

Dans [`variables.tf`](../variables.tf), étendre la validation :

```hcl
validation {
  condition = contains(["splunk", "dynatrace", "elastic", "datadog"], var.observability_platform)
  ...
}
```

Dans [`main.tf`](../main.tf) :

- Ajouter `is_datadog = var.observability_platform == "datadog"` dans les locals.
- Si la plateforme utilise l'OTel Operator, définir sa `instrumentation_ref` dans
  le calcul de `local.instrumentation_ref` (nom **statique** partagé avec le
  module — pas de sortie de module, pour éviter un cycle).
- Ajouter le bloc `module "observability_datadog"` avec
  `count = local.deploy_obs && local.is_datadog ? 1 : 0`.
- Étendre `local.obs_ready` (coalesce) avec le `ready_token` du nouveau module.

## 4. Dimensionnement AKS

Si la plateforme nécessite un pool dédié (comme Elastic), adapter la logique
`is_elastic` / `node_pool_count` et le module `azure-infra` (variable
`is_<platform>` déclenchant le pool). Sinon, aucun changement : les agents
s'exécutent sur les nœuds existants.

## 5. Documentation

Compléter [`modules.md`](modules.md) et le tableau des variables du
[README](../README.md).
