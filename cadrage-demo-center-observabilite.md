# Document de cadrage — Demo Center Observabilité

## 1. Objectif du projet

Créer un **centre de démonstration déployable à la demande** sur une souscription Azure, permettant de présenter une application instrumentée (Easy Trade, projet open source diffusé par Dynatrace) avec une **plateforme d'observabilité configurable au moment du déploiement**, au choix parmi :

- **Splunk** (Splunk Observability Cloud)
- **Dynatrace**
- **Elastic** (via Elastic Cloud on Kubernetes — ECK déployé localement dans le cluster)

Le but est de permettre à des équipes commerciales/techniques de lancer rapidement une démo complète et cohérente, sans configuration manuelle, tout en gardant la possibilité de reprendre le projet à la main plus tard.

---

## 2. Architecture globale

- **Cloud** : Microsoft Azure
- **Orchestration infra** : Terraform (approche modulaire)
- **Compute** : AKS (Azure Kubernetes Service), multi-nœuds
- **Application de démo** : Easy Trade (projet open source Dynatrace)
- **Instrumentation applicative** :
  - Splunk : Splunk Distribution of OpenTelemetry Collector (DaemonSet), avec OpenTelemetry Operator pour l'auto-instrumentation zero-code
  - Dynatrace : Dynatrace Operator en mode `cloudNativeFullStack` (injection par pod)
  - Elastic : EDOT (Elastic Distribution of OpenTelemetry) via `opentelemetry-kube-stack`, avec OpenTelemetry Operator intégré
- **Destinations d'observabilité** :
  - Splunk : instance **Splunk Observability Cloud** de démo existante (access token + realm)
  - Dynatrace : instance de démo existante (URL de tenant + API token)
  - Elastic : instance **ECK déployée localement dans le cluster** (pas d'instance externe)
- **Exposition publique** : Easy Trade et Kibana (Elastic uniquement) exposés sur Internet via Ingress Controller + LoadBalancer Azure
- **Gestion des credentials** : Azure Key Vault **persistant** (hors périmètre Terraform de la démo, dans un resource group dédié) — concerne uniquement Splunk et Dynatrace ; les credentials Elastic sont générés par l'opérateur ECK au déploiement
- **State Terraform** : backend `azurerm` sur Azure Storage Account **persistant** (hors périmètre Terraform de la démo, dans le même resource group dédié que le Key Vault) — permet à plusieurs personnes de déployer depuis des postes différents

---

## 3. Dimensionnement des node pools AKS

Le dimensionnement est **conditionnel à la plateforme choisie**. Le pool `observability` n'est justifié que pour Elastic (ECK = Elasticsearch + Kibana sont des charges de travail réelles). Pour Splunk et Dynatrace, les agents (DaemonSet / injection par pod) s'exécutent directement sur les nœuds existants : aucun nœud dédié n'est nécessaire.

### Splunk et Dynatrace (2 pools)

| Node pool | Rôle | SKU | Nombre de nœuds |
|---|---|---|---|
| `system` | Composants système AKS | `Standard_D2s_v5` (2 vCPU / 8 Go) | 1 |
| `easytrade` | Easy Trade + agents OTel/OneAgent en DaemonSet | `Standard_D4s_v5` (4 vCPU / 16 Go) | 1 |

### Elastic (3 pools)

| Node pool | Rôle | SKU | Nombre de nœuds |
|---|---|---|---|
| `system` | Composants système AKS | `Standard_D2s_v5` (2 vCPU / 8 Go) | 1 |
| `easytrade` | Easy Trade + collecteurs EDOT en DaemonSet | `Standard_D4s_v5` (4 vCPU / 16 Go) | 1 |
| `observability` | ECK : Elasticsearch + Kibana | `Standard_D4s_v5` (4 vCPU / 16 Go) | 2 |

> Ces tailles sont un point de départ ; à ajuster après un premier déploiement test en fonction du volume de données générées par Easy Trade.
> **Autoscaling désactivé** sur tous les pools (comportement prévisible en démo).

---

## 4. Séquencement du déploiement

Le déploiement se fait **en deux temps**, dans un ordre volontairement pédagogique :

**Étape 1 — Infrastructure et application**
Terraform crée l'infrastructure Azure (resource group, réseau, AKS, Ingress Controller) et déploie Easy Trade. On montre que l'infrastructure est opérationnelle et que l'application tourne et est accessible sur Internet, sans observabilité.

**Étape 2 — Couche d'observabilité**
Terraform déploie la plateforme choisie (collecteurs, Operator, ECK selon le cas). Cette étape déclenchant un **rollout restart automatique des deployments Easy Trade** (nécessaire pour que l'injection d'instrumentation prenne effet — point pédagogique fort : "regardez, on redémarre et les traces apparaissent immédiatement").

> Pour Dynatrace en mode `cloudNativeFullStack`, un redémarrage des pods est également requis pour que l'injection par pod s'active.

---

## 5. Sélection de la plateforme

- Le choix de la plateforme (Splunk / Dynatrace / Elastic) se fait **via une variable Terraform avec prompt interactif** lors du déploiement, avec validation (`validation` block).
- Le nombre de nœuds AKS et les modules déployés sont déterminés conditionnellement par cette variable.
- Quelques confirmations pour les choix sensibles sont souhaitées (plateforme, destruction de l'environnement).

---

## 6. Structure Terraform (modulaire)

```
.
├── main.tf
├── variables.tf
├── outputs.tf
├── environments/
│   └── demo/
│       └── terraform.tfvars
└── modules/
    ├── azure-infra/        # Resource group, réseau, AKS, Ingress Controller, IP publiques
    ├── kubernetes-apps/    # Easy Trade (helm_release OCI), Ingress rules, rollout restart
    └── observability/
        ├── splunk/         # Splunk OTel Collector Helm chart + OTel Operator + auto-instrumentation
        ├── dynatrace/      # Dynatrace Operator Helm chart, mode cloudNativeFullStack
        └── elastic-eck/    # ECK Operator, Elasticsearch, Kibana, EDOT kube-stack, Ingress Kibana
```

---

## 7. Déploiement de Easy Trade

Easy Trade se déploie via le chart Helm officiel Dynatrace (OCI registry). Le module Terraform `kubernetes-apps` utilise le provider `helm` (ressource `helm_release`) :

```bash
helm install easytrade oci://europe-docker.pkg.dev/dynatrace-demoability/helm/easytrade \
  --create-namespace --namespace easytrade
```

**Générateur de charge et problem patterns** : Easy Trade embarque un générateur de trafic et des "problem patterns" activables (simulation d'anomalies, erreurs, ralentissements). Ces fonctionnalités sont à activer via les valeurs du chart Helm au déploiement — elles sont essentielles en démo d'observabilité pour démontrer la détection d'incidents en temps réel.

**Exposition publique** : Easy Trade doit être accessible depuis Internet. Un Ingress + Service `LoadBalancer` est créé automatiquement, provisionnant une IP publique Azure. L'URL publique est exposée en output Terraform à la fin du déploiement.

---

## 8. Configuration de l'instrumentation par plateforme

### Splunk

- Déploiement du **Splunk Distribution of OpenTelemetry Collector** via Helm (`splunk-otel-collector-chart`), mode DaemonSet sur tous les nœuds du cluster.
- Destination : **Splunk Observability Cloud** (access token + realm récupérés depuis Key Vault).
- Le chart intègre la possibilité de déployer l'**OpenTelemetry Operator** upstream pour l'auto-instrumentation zero-code (`operator.enabled=true`, `operatorcrds.install=true`) — à activer pour instrumenter les pods Easy Trade automatiquement via annotations namespace.
- Les annotations OTel sont appliquées sur le **namespace `easytrade`** entier (pas pod par pod) pour contourner le fait que le chart Easy Trade est figé.

### Dynatrace

- Déploiement du **Dynatrace Operator** via Helm, mode **`cloudNativeFullStack`** (injection par pod, Kubernetes-native).
- Configuration via URL du tenant Dynatrace + API token récupérés depuis Key Vault.
- Nécessite un rollout restart des pods Easy Trade après déploiement de l'Operator.

### Elastic

- **ECK** : déploiement du `eck-operator` via Helm (`elastic/eck-operator`), puis ressources Elasticsearch et Kibana via le chart `eck-stack`.
- **EDOT** : déploiement de l'Elastic Distribution of OpenTelemetry via le chart `opentelemetry-kube-stack`, qui déploie :
  - l'OpenTelemetry Operator
  - un collecteur EDOT en DaemonSet (métriques niveau nœud)
  - un collecteur EDOT en Deployment (métriques niveau cluster)
  - un objet `Instrumentation` pour l'auto-instrumentation des apps annotées
- Les credentials Elasticsearch (endpoint interne + API key) sont **générés par ECK au déploiement**, pas stockés dans Key Vault — Terraform les récupère via un `data "kubernetes_secret"` après création du cluster Elasticsearch.
- **Kibana exposé sur Internet** : même approche qu'Easy Trade (Ingress + LoadBalancer Azure), URL exposée en output Terraform.

---

## 9. Garde-fous et gestion des coûts

La démo est conçue pour tourner quelques heures. Plusieurs mécanismes de garde-fous doivent être implémentés :

- **Budget alert Azure** : alerte configurée via Terraform sur le resource group de la démo, avec seuil en euros/jour et notification par email au déploiement.
- **Auto-destroy programmé** : un mécanisme de destruction automatique doit être prévu si la démo n'a pas été détruite manuellement après X heures (options : Azure Automation Account avec runbook, ou simple script CI/CD avec timer). À préciser selon les outils disponibles.
- **Output clair en fin de déploiement** : Terraform doit afficher l'heure de déploiement, le coût horaire estimé, et un rappel explicite de la commande `terraform destroy` à exécuter.
- **Autoscaling désactivé** sur les node pools (voir section 3) pour éviter une montée en charge imprévue.

---

## 10. Nettoyage complet en fin de démo (exigence critique)

**Rien ne doit subsister après la destruction de la démo.** Points d'attention spécifiques :

**Load Balancers Azure** : les Services Kubernetes de type `LoadBalancer` (Ingress Controller, Kibana) créent des ressources Azure hors du state Terraform. Ils doivent être **supprimés par Kubernetes avant que Terraform ne détruise le cluster AKS**, sinon ils restent orphelins dans le resource group. Le `terraform destroy` doit être ordonné correctement (via `depends_on` ou destroy provisioners).

**PVC/PV Elasticsearch (Elastic uniquement)** :
- Utiliser une `StorageClass` avec `reclaimPolicy: Delete` pour les PVC d'Elasticsearch.
- Ajouter un `null_resource` avec `local-exec` qui exécute `kubectl delete pvc --all -n elastic-stack` avant la destruction des ressources Kubernetes, pour garantir la suppression des PVC orphelins.
- Les Azure Disks sous-jacents doivent être vérifiés après destroy.

**Key Vault et Storage Account (persistants, hors périmètre)** : ces deux ressources ne doivent **pas** être détruites par le `terraform destroy` de la démo — elles sont dans un resource group séparé non géré par ce projet. Leur coût mensuel combiné est inférieur à $1 (Key Vault facturé à $0,03 pour 10 000 opérations, pas de frais de stockage ; Storage Account à $0,018/Go/mois pour quelques Ko de state Terraform), ce qui justifie pleinement de les conserver en permanence pour éviter de re-saisir les credentials et de reconfigurer le backend à chaque cycle de démo.

**Checklist de vérification post-destroy** (à inclure dans la documentation) :
```bash
# Vérifier que le resource group de la démo est vide ou supprimé
az resource list --resource-group rg-demo-observabilite

# Vérifier l'absence de disques managés résiduels
az disk list --resource-group rg-demo-observabilite

# Vérifier l'absence d'IP publiques orphelines
az network public-ip list --resource-group rg-demo-observabilite
```

---

## 11. Exposition publique

| Composant | Exposé | Mécanisme |
|---|---|---|
| Easy Trade | Oui | Ingress + LoadBalancer Azure |
| Kibana (Elastic) | Oui | Ingress + LoadBalancer Azure |
| Elasticsearch API | Non | Accès interne cluster uniquement |
| Splunk / Dynatrace | N/A | Instances externes, accès via leurs propres URLs |

Chaque URL publique est exposée en **output Terraform** à la fin du déploiement.

**Note sécurité** : pour une démo exposée quelques heures, prévoir a minima une allowlist d'IP sur l'Ingress si les participants sont sur un réseau connu, pour éviter toute exposition non maîtrisée.

---

## 12. Exigences de documentation

Le projet doit inclure une documentation complète permettant une **reprise en main manuelle** :

- Prérequis et versions (Terraform, Azure CLI, kubectl, Helm)
- Guide de déploiement pas-à-pas (étape 1 infra + appli, étape 2 observabilité)
- Description de chaque module Terraform (rôle, variables d'entrée, outputs)
- Guide de gestion des credentials dans Key Vault
- Guide pour ajouter une nouvelle plateforme d'observabilité
- Procédure de destruction complète + checklist de vérification
- Guide de dépannage des cas courants (pods en pending, instrumentation non active, etc.)

---

## 13. Infrastructure persistante (hors démo)

Un **resource group Azure dédié et permanent** (`rg-demo-center-infra`) est à créer manuellement une seule fois, en dehors du périmètre Terraform de la démo. Il contient :

- **Azure Key Vault** : credentials Splunk (access token + realm) et Dynatrace (tenant URL + API token)
- **Azure Storage Account** : backend Terraform partagé pour le state de la démo (accessible par tous les déployeurs)

Ces ressources ne sont jamais touchées par un `terraform destroy` de la démo. Leur coût mensuel combiné est inférieur à $1, ce qui les rend négligeables même si plusieurs semaines séparent deux démos.

---

*Document rédigé pour cadrer une implémentation confiée à Claude Code.*
