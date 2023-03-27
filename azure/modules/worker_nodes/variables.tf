variable "resource_group_name" {
  description = "The resource group name"
}

variable "subnet_id" {
  description = "The subnet ID"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}

variable "location" {
  description = "The Azure Region"
  default     = "East US"
}

# variable "ssh_private_key" {
#   description = "The SSH private key"
#   default     = "~/.ssh/acloudguru"
# }

variable "vm_private_ips" {
  description = "The private IP addresses of the Masters VMs"
  type        = list(string)
}

variable "public_ip_addresses" {
  description = "The public IP addresses of the Masters VMs"
  type        = list(string)
}

