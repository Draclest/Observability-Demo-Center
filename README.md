# Demo Center Observabilité

Centre de démonstration **déployable à la demande** sur Azure : une application
instrumentée (**Easy Trade**, projet open source Dynatrace) sur **AKS**, avec une
plateforme d'observabilité choisie au moment du déploiement parmi **Splunk**,
**Dynatrace** ou **Elastic** (ECK déployé localement dans le cluster).

Objectif : lancer rapidement une démo complète et cohérente, sans configuration
manuelle, tout en gardant la possibilité de reprendre le projet à la main.

---

## Sommaire

- [Prérequis](#prérequis)
- [Architecture](#architecture)
- [Démarrage rapide](#démarrage-rapide)
- [Déploiement pas-à-pas](#déploiement-pas-à-pas)
- [Variables principales](#variables-principales)
- [Destruction + checklist](#destruction--checklist)
- [Documentation détaillée](#documentation-détaillée)

---

## Prérequis

| Outil | Version | Rôle |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.5 | Orchestration infra |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | récente | Authentification (`az login`) |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | récente | Accès AKS, rollout restart, nettoyage |
| [Helm](https://helm.sh/docs/intro/install/) | ≥ 3.8 | Utilisé par Terraform (provider helm) |

- Une souscription Azure avec le rôle **Owner** (attributions de rôle requises).
- Authentification : `az login` (aucun secret stocké).

---

## Architecture

- **Cloud** : Azure — **Compute** : AKS multi-nœuds (node pools conditionnels).
- **Terraform modulaire** :

```
.
├── bootstrap/              # Infra persistante (RG dédié, backend, Key Vault) — HORS destroy
├── main.tf                 # Assemblage + logique conditionnelle par plateforme
├── variables.tf            # Variables racine (dont observability_platform)
├── outputs.tf              # URLs publiques + récapitulatif de fin
├── cleanup.tf              # Rollout restart + nettoyage ordonné (LB, PVC)
├── providers.tf            # azurerm, kubernetes, helm, kubectl
├── versions.tf / backend.tf
├── environments/demo/      # backend.hcl + terraform.tfvars
└── modules/
    ├── azure-infra/        # RG, VNet, AKS, NGINX Ingress, cert-manager, IP statique, budget, auto-destroy
    ├── kubernetes-apps/    # Easy Trade (chart OCI), Ingress, TLS
    └── observability/
        ├── splunk/         # Splunk OTel Collector + OTel Operator
        ├── dynatrace/      # Dynatrace Operator (cloudNativeFullStack)
        └── elastic-eck/    # ECK + Elasticsearch + Kibana + EDOT
```

- **Node pools** (autoscaling désactivé) :
  - Splunk / Dynatrace : `system` + `easytrade` (2 pools).
  - Elastic : `system` + `easytrade` + `observability` ×2 (3 pools).
- **Exposition** : Easy Trade (+ Kibana pour Elastic) via NGINX Ingress + IP
  publique **statique**, hostnames `nip.io` déterministes, TLS auto-signé
  (cert-manager). Elasticsearch reste interne.
- **Credentials** : Key Vault persistant (Splunk/Dynatrace) ; Elastic auto-généré
  par ECK.
- **State** : backend `azurerm` sur Storage Account persistant.

---

## Démarrage rapide

```bash
# 0. Bootstrap (UNE seule fois) — crée le RG persistant, le backend et le Key Vault
az login
cd bootstrap
./bootstrap.ps1 -SubscriptionId "<subscription-id>"
# → saisir ensuite les credentials Splunk/Dynatrace (commandes affichées)
cd ..

# 1. Renseigner environments/demo/backend.hcl et terraform.tfvars
#    (valeurs affichées par le bootstrap : storage account, key vault, suffix)

# 2. Init + Étape 1 (infra + application)
terraform init -backend-config=environments/demo/backend.hcl
terraform apply -var-file=environments/demo/terraform.tfvars

# 3. Étape 2 (couche d'observabilité + rollout restart)
terraform apply -var-file=environments/demo/terraform.tfvars \
  -var 'deploy_observability_layer=true'

# 4. FIN DE DÉMO — tout détruire
terraform destroy -var-file=environments/demo/terraform.tfvars \
  -var 'deploy_observability_layer=true'
```

---

## Déploiement pas-à-pas

### Bootstrap (une fois)

Voir [`bootstrap/README.md`](bootstrap/README.md). Crée le resource group
persistant `rg-demo-center-infra` (Storage Account + Key Vault), affiche les
valeurs à reporter dans `environments/demo/`. Détaillé aussi dans
[`docs/credentials.md`](docs/credentials.md).

### Étape 1 — Infrastructure + application

```bash
terraform apply -var-file=environments/demo/terraform.tfvars
```

Crée le RG de la démo, le réseau, l'AKS (avec les node pools adaptés à la
plateforme choisie), l'Ingress Controller NGINX, cert-manager, l'alerte de budget
et le mécanisme d'auto-destroy, puis déploie Easy Trade **sans observabilité**.
À la fin, l'output `easytrade_url` donne l'URL publique.

> Pédagogie : on montre l'application qui tourne et est accessible, **avant** toute
> instrumentation.

### Étape 2 — Couche d'observabilité

```bash
terraform apply -var-file=environments/demo/terraform.tfvars \
  -var 'deploy_observability_layer=true'
```

Déploie la plateforme choisie (collecteurs / Operator / ECK selon le cas), pose
les annotations d'auto-instrumentation sur le namespace `easytrade` (Splunk /
Elastic) et déclenche un **rollout restart** des deployments Easy Trade : les
traces apparaissent immédiatement dans la plateforme.

Pour Elastic, l'output `kibana_url` donne l'URL de Kibana.

---

## Variables principales

| Variable | Défaut | Rôle |
|---|---|---|
| `observability_platform` | *(requis)* | `splunk` \| `dynatrace` \| `elastic` |
| `deploy_observability_layer` | `false` | Séquencement 2 temps (Étape 1 / Étape 2) |
| `subscription_id` | *(requis)* | Souscription Azure cible |
| `location` | `westeurope` | Région |
| `key_vault_name` / `key_vault_rg` | *(requis)* / `rg-demo-center-infra` | Key Vault persistant |
| `allowed_ip_ranges` | `[]` | Allowlist IP sur l'Ingress (vide = ouvert) |
| `auto_destroy_ttl_hours` | `8` | Délai avant auto-destroy du RG |
| `budget_amount_eur` | `100` | Budget mensuel (alerte) |
| `budget_contact_emails` | `[]` | Destinataires des alertes |
| `easytrade_loadgen_enabled` | `true` | Générateur de charge |
| `easytrade_problem_patterns_enabled` | `true` | Problem patterns |

Liste complète dans [`variables.tf`](variables.tf) et par module dans
[`docs/modules.md`](docs/modules.md).

---

## Destruction + checklist

```bash
terraform destroy -var-file=environments/demo/terraform.tfvars \
  -var 'deploy_observability_layer=true'
```

L'ordre est géré automatiquement : les Services LoadBalancer et les PVC
Elasticsearch sont supprimés **avant** la destruction du cluster (voir
[`cleanup.tf`](cleanup.tf)). Le Key Vault et le Storage Account persistants ne
sont **jamais** touchés.

**Checklist post-destroy** (voir [`docs/troubleshooting.md`](docs/troubleshooting.md)) :

```bash
az resource list        --resource-group rg-demo-observabilite -o table
az disk list            --resource-group rg-demo-observabilite -o table
az network public-ip list --resource-group rg-demo-observabilite -o table
```

Tout doit être vide (ou le RG supprimé).

---

## Documentation détaillée

- [`docs/modules.md`](docs/modules.md) — rôle, variables et outputs de chaque module.
- [`docs/credentials.md`](docs/credentials.md) — gestion des credentials dans le Key Vault.
- [`docs/add-platform.md`](docs/add-platform.md) — ajouter une nouvelle plateforme d'observabilité.
- [`docs/troubleshooting.md`](docs/troubleshooting.md) — dépannage + checklist de destruction.

---

## Notes

- **Lock file providers** : `.terraform.lock.hcl` est ignoré par git (les hashes
  sont générés par plateforme). Pour figer les versions en multi-poste, lancez
  `terraform providers lock -platform=windows_amd64 -platform=linux_amd64 -platform=darwin_arm64`.
- **Charts d'observabilité** : les versions et certaines valeurs (notamment
  `opentelemetry-kube-stack` pour EDOT et la CRD `DynaKube`) évoluent ; elles sont
  paramétrées en variables et à vérifier avant un premier déploiement — voir
  [`docs/troubleshooting.md`](docs/troubleshooting.md).
