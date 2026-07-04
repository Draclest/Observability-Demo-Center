# Bootstrap — Infrastructure persistante

Ce dossier crée, **une seule fois**, l'infrastructure Azure **persistante** partagée
par tous les déployeurs de la démo. Ces ressources vivent dans un resource group
dédié (`rg-demo-center-infra`) et **ne sont jamais détruites** par le
`terraform destroy` de la démo.

## Ce qui est créé

| Ressource | Rôle |
|---|---|
| Resource group `rg-demo-center-infra` | Conteneur des ressources persistantes |
| Storage Account `stdemocenter<suffix>` + container `tfstate` | Backend Terraform (state partagé) |
| Key Vault `kv-democenter-<suffix>` | Credentials Splunk et Dynatrace |

> `<suffix>` = 6 derniers caractères alphanumériques de l'ID de souscription.
> Il rend les noms **stables et uniques par souscription** : ré-exécuter le script
> réutilise les ressources existantes (idempotent), il ne recrée rien.

**Coût mensuel combiné : < 1 $** (Key Vault facturé à l'opération, Storage à
~0,018 $/Go/mois pour quelques Ko de state). Justifie de les conserver en
permanence pour ne pas re-saisir les credentials ni reconfigurer le backend.

## Prérequis

- **Azure CLI** (`az`) — `winget install Microsoft.AzureCLI`
- Être **connecté** : `az login`
- Rôle **Owner** (ou Contributor + User Access Administrator) sur la souscription

## Utilisation

```powershell
# Depuis le dossier bootstrap/
az login

# Création des ressources (affiche les commandes de seeding des secrets à la fin)
./bootstrap.ps1 -SubscriptionId "a4ea47dc-5393-40e6-af33-f9693c503310"

# Variante : saisir les credentials Splunk/Dynatrace de façon interactive
./bootstrap.ps1 -SubscriptionId "..." -SeedSecrets
```

Paramètres :

| Paramètre | Défaut | Description |
|---|---|---|
| `-SubscriptionId` | *(requis)* | ID de la souscription cible |
| `-Location` | `westeurope` | Région Azure |
| `-InfraResourceGroup` | `rg-demo-center-infra` | Nom du RG persistant |
| `-SeedSecrets` | *(off)* | Saisie interactive des credentials |

## Secrets attendus dans le Key Vault

Seuls les secrets de la **plateforme démontrée** sont nécessaires :

| Secret | Plateforme | Contenu |
|---|---|---|
| `splunk-access-token` | Splunk | Access token Splunk Observability Cloud |
| `splunk-realm` | Splunk | Realm (ex. `eu0`) |
| `dynatrace-api-url` | Dynatrace | URL du tenant (`https://xxx.live.dynatrace.com`) |
| `dynatrace-api-token` | Dynatrace | API token |

Elastic n'a besoin d'**aucun** secret : les credentials Elasticsearch sont générés
par l'opérateur ECK au déploiement.

## Après le bootstrap

Le script affiche les valeurs à reporter dans :

- `environments/demo/backend.hcl` — configuration du backend Terraform
- `environments/demo/terraform.tfvars` — `subscription_id`, `key_vault_name`, `key_vault_rg`

Puis, à la racine du projet :

```bash
terraform init -backend-config=environments/demo/backend.hcl
```

## Donner accès à d'autres déployeurs

Le script accorde l'accès aux secrets à l'utilisateur qui l'exécute. Pour ajouter
un collègue :

```bash
az keyvault set-policy --name kv-democenter-<suffix> \
  --object-id <object-id-utilisateur> \
  --secret-permissions get list
```
