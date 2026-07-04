# Configuration du backend Terraform (state sur Azure Storage persistant).
# Valeurs fournies par le script bootstrap/bootstrap.ps1.
# Utilisation : terraform init -backend-config=environments/demo/backend.hcl
#
# Remplacez <suffix> par les 6 derniers caracteres alphanumeriques de votre
# ID de souscription (affiches par le script de bootstrap).

resource_group_name  = "rg-demo-center-infra"
storage_account_name = "stdemocenter<suffix>"
container_name       = "tfstate"
key                  = "demo.terraform.tfstate"
