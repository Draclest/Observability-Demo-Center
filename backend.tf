# Backend Terraform : Azure Storage Account PERSISTANT (cree par le bootstrap,
# hors perimetre du `terraform destroy` de la demo).
#
# La configuration est volontairement PARTIELLE : les valeurs concretes
# (resource_group_name, storage_account_name, container_name, key) sont fournies
# a l'init via un fichier de backend, pour ne pas figer d'identifiants dans le code
# et permettre a plusieurs personnes de deployer depuis des postes differents :
#
#   terraform init -backend-config=environments/demo/backend.hcl
#
# Le fichier environments/demo/backend.hcl est genere a partir des valeurs
# affichees par le script bootstrap/bootstrap.ps1.
terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
