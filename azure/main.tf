provider "azurerm" {
  features {}
  skip_provider_registration = true
}

locals {
  common_tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# resource "azurerm_resource_group" "rke2" {
#   name     = "rke2-resource-group"
#   location = "East US"
#   tags     = local.common_tags
# }

module "network" {
  source              = "./modules/network"
  resource_group_name = var.resource_group_name
  tags                = local.common_tags
}

module "master_nodes" {
  source              = "./modules/master_nodes"
  resource_group_name = var.resource_group_name
  subnet_id           = module.network.subnet_id
  tags                = local.common_tags
  depends_on          = [module.network]
}

module "worker_nodes" {
  source              = "./modules/worker_nodes"
  resource_group_name = var.resource_group_name
  subnet_id           = module.network.subnet_id
  vm_private_ips      = module.master_nodes.vm_private_ips
  public_ip_addresses = module.master_nodes.public_ip_addresses
  tags                = local.common_tags
  depends_on          = [module.master_nodes]
}
