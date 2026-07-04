# ==============================================================================
# Alerte de budget Azure sur le resource group de la demo
# ==============================================================================

locals {
  # Debut de periode : premier jour du mois courant (exige par l'API budget).
  budget_start = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  budget_end   = "2030-12-31T00:00:00Z"
}

resource "azurerm_consumption_budget_resource_group" "demo" {
  name              = "${var.prefix}-budget"
  resource_group_id = azurerm_resource_group.demo.id

  amount     = var.budget_amount_eur
  time_grain = "Monthly"

  time_period {
    start_date = local.budget_start
    end_date   = local.budget_end
  }

  # Seuil d'alerte a 80 % du cout reel constate.
  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_emails = var.budget_contact_emails
  }

  # Seuil d'alerte a 100 % (previsionnel) pour anticiper un depassement.
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"
    contact_emails = var.budget_contact_emails
  }

  # start_date derive de timestamp() : on ignore sa derive pour eviter un diff
  # perpetuel au fil des mois.
  lifecycle {
    ignore_changes = [time_period[0].start_date]
  }
}
