# ==============================================================================
# Auto-destroy programme (garde-fou de cout)
#
# Un Automation Account place DANS le RG de la demo execute, apres le TTL, un
# runbook qui supprime le RG. Avantages :
#   - self-contained : disparait avec un `terraform destroy` manuel ;
#   - survit poste eteint (execution cote Azure) ;
#   - sans dependance de module PowerShell (appel REST via identite manageree).
# ==============================================================================

# Instant de deploiement (capture une seule fois) -> base du calcul du TTL.
resource "time_static" "deploy" {}

resource "azurerm_automation_account" "autodestroy" {
  name                = "${var.prefix}-autodestroy"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = var.common_tags
}

# L'identite manageree du compte Automation doit pouvoir supprimer le RG.
resource "azurerm_role_assignment" "autodestroy_contributor" {
  scope                = azurerm_resource_group.demo.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.autodestroy.identity[0].principal_id
}

resource "azurerm_automation_runbook" "autodestroy" {
  name                    = "auto-destroy-rg"
  location                = azurerm_resource_group.demo.location
  resource_group_name     = azurerm_resource_group.demo.name
  automation_account_name = azurerm_automation_account.autodestroy.name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell72"
  description             = "Supprime le RG de la demo apres expiration du TTL."

  content = templatefile("${path.module}/scripts/autodestroy.ps1.tftpl", {
    subscription_id     = var.subscription_id
    resource_group_name = var.resource_group_name
  })

  tags = var.common_tags
}

# Planification unique a l'instant de deploiement + TTL.
resource "azurerm_automation_schedule" "autodestroy" {
  name                    = "auto-destroy-schedule"
  resource_group_name     = azurerm_resource_group.demo.name
  automation_account_name = azurerm_automation_account.autodestroy.name
  frequency               = "OneTime"
  start_time              = timeadd(time_static.deploy.rfc3339, "${var.auto_destroy_ttl_hours}h")
  description             = "Declenche l'auto-destroy apres ${var.auto_destroy_ttl_hours} h."

  # start_time est dans le passe lors des applies ulterieurs : on l'ignore pour
  # eviter une erreur / un diff perpetuel.
  lifecycle {
    ignore_changes = [start_time]
  }
}

resource "azurerm_automation_job_schedule" "autodestroy" {
  resource_group_name     = azurerm_resource_group.demo.name
  automation_account_name = azurerm_automation_account.autodestroy.name
  runbook_name            = azurerm_automation_runbook.autodestroy.name
  schedule_name           = azurerm_automation_schedule.autodestroy.name
}
