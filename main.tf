# Configure the Azure provider

locals {
  stack = "${var.app}-${var.env}-${var.location}"

  default_tags = {
    environment = var.env
    owner       = "GFlisch"
    app         = var.app
  }

}

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

