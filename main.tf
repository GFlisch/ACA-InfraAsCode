# Configure the Azure provider

locals {
  stack = "${var.app}-${var.env}-${var.location}"

  default_tags = {
    environment = var.env
    owner       = "GFlisch"
    app         = var.app
  }

}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "my_app" {
  name     = "rg-${local.stack}"
  location = var.region

  tags = local.default_tags
}



resource "azurerm_log_analytics_workspace" "my_log_analytics" {
  name                = "log-${local.stack}"
  location            = azurerm_resource_group.my_app.location
  resource_group_name = azurerm_resource_group.my_app.name

  tags = local.default_tags
}

resource "azurerm_container_app_environment" "my_app" {
  name                      = "cae-${local.stack}"
  location                   = azurerm_resource_group.my_app.location
  resource_group_name        = azurerm_resource_group.my_app.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.my_log_analytics.id

  tags = local.default_tags
}

resource "azurerm_dns_zone" "dns" {
  name                = "acceptancetest.arc4u.net"
  resource_group_name = azurerm_resource_group.my_app.name
}

resource "azurerm_dns_txt_record" "dns" {
  name                = "asuid.acceptancetest.arc4u.net"
  zone_name           = azurerm_dns_zone.dns.name
  resource_group_name = azurerm_resource_group.my_app.name
  ttl                 = 300

  record {
    value = "8224261506781F996518E27935085891A4429CCE65D1EFD2EA39FA68B00F83E8"
  }
}

resource "azurerm_container_app_environment_custom_domain" "arc4u_net" {
  container_app_environment_id = azurerm_container_app_environment.my_app.id
  certificate_blob_base64 = filebase64("${path.module}/certs/arc4u.net.pfx")
  certificate_password = var.cert_password
  dns_suffix = "acceptancetest.arc4u.net"
}

resource "azurerm_container_app_environment_certificate" "arc4u_net" {
  name = "cert-arc4u.net"
  certificate_blob_base64 = filebase64("${path.module}/certs/arc4u.net.pfx")
  certificate_password = var.cert_password
  container_app_environment_id = azurerm_container_app_environment.my_app.id
}


resource "azurerm_key_vault" "my_app" {
  name                        = "secrets-${local.stack}"
  location                    = azurerm_resource_group.my_app.location
  resource_group_name         = azurerm_resource_group.my_app.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete",
    ]

    secret_permissions = [
      "Get", "List", "Delete", "Set",
    ]

    storage_permissions = [
      "Get", "List",
    ]
  }
}

data "azurerm_key_vault_secret" "acr_id" {
  name         = "acr-service-principal-id"
  key_vault_id = azurerm_key_vault.my_app.id
}

data "azurerm_key_vault_secret" "acr_password" {
  name         = "acr-service-principal-password"
  key_vault_id = azurerm_key_vault.my_app.id
}

data "azurerm_container_registry" "acr" {
  name                = "demoarc4u"
  resource_group_name = "Demo"
}


resource "azurerm_role_assignment" "containerapp" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "acrpull"
  principal_id         = data.azurerm_key_vault_secret.acr_id.value
}


resource "azurerm_container_app" "app1" {
  name                      = "hello"
  resource_group_name       = azurerm_resource_group.my_app.name
  container_app_environment_id = azurerm_container_app_environment.my_app.id
  revision_mode             = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_key_vault_secret.acr_id.value]
  }
 
  registry {
    server   = data.azurerm_container_registry.acr.login_server
    identity = data.azurerm_key_vault_secret.acr_id.value
  }

  template {
    container {
      name   = "examplecontainerapp"
      image  = "${var.registry}/cloudapp1:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}
