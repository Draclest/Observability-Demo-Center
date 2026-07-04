<#
.SYNOPSIS
    Bootstrap de l'infrastructure PERSISTANTE du Demo Center Observabilite.

.DESCRIPTION
    Cree, une seule fois et EN DEHORS du perimetre Terraform de la demo, les
    ressources persistantes partagees par tous les deployeurs :

      - Resource group dedie (rg-demo-center-infra)
      - Storage Account + container "tfstate" -> backend Terraform azurerm
      - Key Vault -> credentials Splunk et Dynatrace

    Ces ressources ne sont JAMAIS detruites par le `terraform destroy` de la demo
    (leur cout mensuel combine est < 1 $). Le script est idempotent : les noms de
    Storage Account et de Key Vault sont derives de l'ID de souscription, donc
    re-executer le script reutilise les memes ressources sans les recreer.

    Le script NE stocke PAS les credentials Splunk/Dynatrace : il affiche a la fin
    les commandes `az keyvault secret set` exactes a lancer (ou passez les valeurs
    en parametres pour un seeding automatique).

.PARAMETER SubscriptionId
    ID de la souscription Azure cible.

.PARAMETER Location
    Region Azure (defaut : westeurope).

.PARAMETER InfraResourceGroup
    Nom du resource group persistant (defaut : rg-demo-center-infra).

.PARAMETER SeedSecrets
    Si present, le script demande interactivement les 4 credentials et les ecrit
    dans le Key Vault. Sinon il affiche seulement les commandes a lancer.

.EXAMPLE
    ./bootstrap.ps1 -SubscriptionId "a4ea47dc-5393-40e6-af33-f9693c503310"

.EXAMPLE
    ./bootstrap.ps1 -SubscriptionId "..." -SeedSecrets
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [string]$Location = "westeurope",

    [string]$InfraResourceGroup = "rg-demo-center-infra",

    [switch]$SeedSecrets
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }

# --- Pre-flight -------------------------------------------------------------
Write-Step "Verification de l'outillage (az)"
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) introuvable. Installez-le : winget install Microsoft.AzureCLI"
}
Write-Ok "az present"

Write-Step "Selection de la souscription"
az account set --subscription $SubscriptionId | Out-Null
$account = az account show --query "{name:name, id:id, user:user.name}" -o json | ConvertFrom-Json
Write-Ok "Souscription : $($account.name) ($($account.id))"
Write-Ok "Utilisateur  : $($account.user)"

# Suffixe stable derive de l'ID de souscription -> idempotence + unicite globale
$suffix = ($SubscriptionId -replace "[^a-zA-Z0-9]", "").ToLower()
$suffix = $suffix.Substring($suffix.Length - 6)

$storageAccount = "stdemocenter$suffix"          # 3-24, minuscules alphanum
$keyVault       = "kv-democenter-$suffix"         # 3-24, alphanum + tirets
$container      = "tfstate"

Write-Ok "Storage Account : $storageAccount"
Write-Ok "Key Vault       : $keyVault"

# --- Resource group ---------------------------------------------------------
Write-Step "Resource group persistant : $InfraResourceGroup"
az group create --name $InfraResourceGroup --location $Location `
    --tags purpose=demo-center-persistent managed-by=bootstrap-script | Out-Null
Write-Ok "Resource group pret"

# --- Storage Account + container (backend Terraform) ------------------------
Write-Step "Storage Account (backend Terraform state)"
$saExists = az storage account check-name --name $storageAccount --query "nameAvailable" -o tsv
if ($saExists -eq "true") {
    az storage account create `
        --name $storageAccount `
        --resource-group $InfraResourceGroup `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 `
        --min-tls-version TLS1_2 `
        --allow-blob-public-access false `
        --tags purpose=demo-center-tfstate | Out-Null
    Write-Ok "Storage Account cree"
} else {
    Write-Ok "Storage Account deja existant (reutilise)"
}

# Versioning du blob pour proteger le state
az storage account blob-service-properties update `
    --account-name $storageAccount `
    --resource-group $InfraResourceGroup `
    --enable-versioning true | Out-Null
Write-Ok "Versioning du state active"

# Container tfstate (auth via identite az login)
az storage container create `
    --name $container `
    --account-name $storageAccount `
    --auth-mode login | Out-Null
Write-Ok "Container '$container' pret"

# --- Key Vault --------------------------------------------------------------
Write-Step "Key Vault (credentials Splunk / Dynatrace)"
$kvExists = az keyvault list --resource-group $InfraResourceGroup `
    --query "[?name=='$keyVault'] | length(@)" -o tsv
if ($kvExists -eq "0") {
    # Modele access-policy (plus simple qu'RBAC pour un usage individuel,
    # pas de delai de propagation de role)
    az keyvault create `
        --name $keyVault `
        --resource-group $InfraResourceGroup `
        --location $Location `
        --enable-rbac-authorization false `
        --tags purpose=demo-center-credentials | Out-Null
    Write-Ok "Key Vault cree"
} else {
    Write-Ok "Key Vault deja existant (reutilise)"
}

# Donner acces a l'utilisateur courant sur les secrets
$currentUserId = az ad signed-in-user show --query id -o tsv
az keyvault set-policy --name $keyVault `
    --object-id $currentUserId `
    --secret-permissions get list set delete | Out-Null
Write-Ok "Acces secrets accorde a l'utilisateur courant"

# --- Seeding des credentials -----------------------------------------------
$secretNames = @{
    "splunk-access-token" = "Splunk Observability Cloud : access token"
    "splunk-realm"        = "Splunk Observability Cloud : realm (ex. eu0)"
    "dynatrace-api-url"   = "Dynatrace : URL du tenant (ex. https://xxx.live.dynatrace.com)"
    "dynatrace-api-token" = "Dynatrace : API token"
}

if ($SeedSecrets) {
    Write-Step "Saisie des credentials (seeding du Key Vault)"
    foreach ($name in $secretNames.Keys) {
        $val = Read-Host "  $($secretNames[$name])"
        if (-not [string]::IsNullOrWhiteSpace($val)) {
            az keyvault secret set --vault-name $keyVault --name $name --value $val | Out-Null
            Write-Ok "Secret '$name' ecrit"
        } else {
            Write-Host "    [SKIP] '$name' vide, ignore" -ForegroundColor Yellow
        }
    }
}

# --- Recapitulatif ----------------------------------------------------------
Write-Step "Bootstrap termine"

Write-Host @"

------------------------------------------------------------------------------
CONFIGURATION DU BACKEND TERRAFORM
------------------------------------------------------------------------------
Renseignez ces valeurs dans environments/demo/backend.hcl :

  resource_group_name  = "$InfraResourceGroup"
  storage_account_name = "$storageAccount"
  container_name       = "$container"
  key                  = "demo.terraform.tfstate"

Puis initialisez Terraform :

  terraform init -backend-config=environments/demo/backend.hcl

------------------------------------------------------------------------------
VARIABLE DE SOUSCRIPTION
------------------------------------------------------------------------------
Dans environments/demo/terraform.tfvars :

  subscription_id     = "$SubscriptionId"
  key_vault_name      = "$keyVault"
  key_vault_rg        = "$InfraResourceGroup"
"@ -ForegroundColor White

if (-not $SeedSecrets) {
    Write-Host @"

------------------------------------------------------------------------------
CREDENTIALS A SAISIR DANS LE KEY VAULT (Splunk et/ou Dynatrace)
------------------------------------------------------------------------------
Lancez uniquement les lignes correspondant a la plateforme que vous demontrez :

  az keyvault secret set --vault-name $keyVault --name splunk-access-token --value "<TOKEN>"
  az keyvault secret set --vault-name $keyVault --name splunk-realm        --value "<REALM>"
  az keyvault secret set --vault-name $keyVault --name dynatrace-api-url    --value "<URL_TENANT>"
  az keyvault secret set --vault-name $keyVault --name dynatrace-api-token  --value "<TOKEN>"

(Elastic ne necessite aucun secret : les credentials sont generes par ECK.)
"@ -ForegroundColor White
}

Write-Host "`nTermine.`n" -ForegroundColor Green
