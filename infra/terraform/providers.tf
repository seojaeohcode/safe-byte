provider "ncloud" {
  access_key  = var.ncloud_access_key != null ? var.ncloud_access_key : null
  secret_key  = var.ncloud_secret_key != null ? var.ncloud_secret_key : null
  region      = var.region
  site        = var.site
  support_vpc = true
}
