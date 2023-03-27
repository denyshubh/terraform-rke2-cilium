variable "resource_group_name" {
  description = "The resource group name"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}
