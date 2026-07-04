# Demo Center Observabilité

Centre de démonstration **déployable à la demande** sur Azure : une application
instrumentée (**Easy Trade**, projet open source Dynatrace) sur **AKS**, avec une
plateforme d'observabilité choisie au déploiement parmi **Splunk**, **Dynatrace**
ou **Elastic** (ECK local).

> Documentation en cours de construction — ce README sera complété en Phase 5
> (déploiement pas-à-pas, description des modules, dépannage, checklist de destroy).

## Prérequis

| Outil | Rôle |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5 | Orchestration infra |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | Authentification (`az login`) |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Accès au cluster AKS |
| [Helm](https://helm.sh/docs/intro/install/) | Déploiement des charts |

## Vue d'ensemble du déploiement

1. **Bootstrap (une seule fois)** — créer l'infra persistante (backend + Key Vault) :
   voir [`bootstrap/README.md`](bootstrap/README.md).
2. **Étape 1 — Infra + application** : Terraform crée le RG, le réseau, l'AKS,
   l'Ingress Controller et déploie Easy Trade (sans observabilité).
3. **Étape 2 — Observabilité** : Terraform déploie la plateforme choisie et
   redémarre Easy Trade pour activer l'instrumentation.

```bash
az login
az account set --subscription <subscription-id>

# Init (backend renseigné par le bootstrap)
terraform init -backend-config=environments/demo/backend.hcl

# Déploiement
terraform apply -var-file=environments/demo/terraform.tfvars
```

## Structure

```
.
├── bootstrap/              # Infra persistante (RG dédié, backend, Key Vault) — hors destroy
├── main.tf                 # Assemblage + logique conditionnelle par plateforme
├── variables.tf            # Variables racine (dont observability_platform)
├── outputs.tf              # URLs publiques + récapitulatif de fin
├── providers.tf            # azurerm, kubernetes, helm, kubectl
├── versions.tf             # Contraintes Terraform / providers
├── backend.tf              # Backend azurerm (config partielle)
├── environments/
│   └── demo/
│       ├── backend.hcl     # Config backend (généré par le bootstrap)
│       └── terraform.tfvars
└── modules/
    ├── azure-infra/        # RG, réseau, AKS, Ingress Controller, IP publiques
    ├── kubernetes-apps/    # Easy Trade, Ingress rules, rollout restart
    └── observability/
        ├── splunk/
        ├── dynatrace/
        └── elastic-eck/
```

## ⚠️ Destruction

La démo est conçue pour tourner **quelques heures**. Un runbook d'auto-destroy la
supprime après `auto_destroy_ttl_hours` (défaut 8 h), mais **détruisez-la
manuellement** dès la fin :

```bash
terraform destroy -var-file=environments/demo/terraform.tfvars
```

La procédure complète et la checklist de vérification post-destroy seront
documentées en Phase 5.
