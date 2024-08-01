variable "region" {
  description = "Azure infrastructure region"
  type    = string
  default = "westeurope"
}

variable "app" {
  description = "Application that we want to deploy"
  type    = string
  default = "arc4u1"
}

variable "env" {
  description = "Application env"
  type    = string
  default = "dev"
}

variable "location" {
  description = "Location short name "
  type    = string
  default = "we"
}

variable "cert_password" {
  description = "Password of the certificate"
  type    = string
  sensitive   = true
}

variable "registry" {
  description = "registry address"
  type    = string
  default = "demoarc4u.azurecr.io"
}

