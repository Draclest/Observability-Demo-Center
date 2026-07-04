# Gestion des credentials (Key Vault persistant)

Les credentials **Splunk** et **Dynatrace** sont stockés dans un **Azure Key
Vault persistant**, créé une seule fois par le [bootstrap](../bootstrap/README.md)
dans le resource group `rg-demo-center-infra` (hors périmètre du `terraform
destroy` de la démo). **Elastic n'a besoin d'aucun secret** : les credentials
Elasticsearch sont générés par l'opérateur ECK au déploiement.

## Secrets attendus

| Secret | Plateforme | Contenu |
|---|---|---|
| `splunk-access-token` | Splunk | Access token Splunk Observability Cloud |
| `splunk-realm` | Splunk | Realm (ex. `eu0`) |
| `dynatrace-api-url` | Dynatrace | URL du tenant **sans** `/api` (ex. `https://xxx.live.dynatrace.com`) |
| `dynatrace-api-token` | Dynatrace | API token (scopes voir ci-dessous) |

> ⚠️ Stockez l'URL Dynatrace **sans** le suffixe `/api` : le module l'ajoute
> automatiquement.

## Saisir / mettre à jour un secret

```bash
az keyvault secret set --vault-name kv-democenter-<suffix> \
  --name splunk-access-token --value "<TOKEN>"
```

Le nom exact du Key Vault (`kv-democenter-<suffix>`) est affiché par le script de
bootstrap et doit être reporté dans `environments/demo/terraform.tfvars`
(`key_vault_name`).

## Comment Terraform lit ces secrets

Chaque sous-module d'observabilité concerné lit le Key Vault via des `data`
sources :

```hcl
data "azurerm_key_vault"        "kv"  { name = var.key_vault_name, resource_group_name = var.key_vault_rg }
data "azurerm_key_vault_secret" "..." { name = "<secret>", key_vault_id = data.azurerm_key_vault.kv.id }
```

L'utilisateur qui lance `terraform apply` doit avoir l'accès **secrets get/list**
sur le Key Vault (accordé par le bootstrap à l'utilisateur qui l'exécute).

## Donner l'accès à un autre déployeur

```bash
az keyvault set-policy --name kv-democenter-<suffix> \
  --object-id <object-id-utilisateur> --secret-permissions get list
```

Récupérer l'object-id : `az ad user show --id <email> --query id -o tsv`.

## Tokens / scopes recommandés

- **Splunk** : un access token d'ingestion (org token) valide pour le realm.
- **Dynatrace** : API token avec au minimum les scopes de déploiement
  Kubernetes/ActiveGate (`Create ActiveGate tokens`,
  `Kubernetes API monitoring`, etc.) — se référer à la documentation Dynatrace de
  l'opérateur pour la liste exacte selon la version.
