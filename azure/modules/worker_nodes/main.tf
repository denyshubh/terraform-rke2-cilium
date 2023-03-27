
resource "azurerm_public_ip" "worker_public_ip" {
  count               = 2
  name                = "worker-pub2-ip-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
  domain_name_label   = "unique-pub2-worker${count.index}" # <-- Change this value
  tags                = var.tags
}

resource "azurerm_network_interface" "worker_nic" {
  count               = 2
  name                = "worker-nic-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "worker-ipconfig-${count.index}"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.worker_public_ip[count.index].id
  }
}

resource "azurerm_virtual_machine" "worker_vm" {
  count                            = 2
  name                             = "worker-vm-${count.index}"
  location                         = var.location
  resource_group_name              = var.resource_group_name
  network_interface_ids            = [azurerm_network_interface.worker_nic[count.index].id]
  vm_size                          = "Standard_D2s_v3"
  tags                             = var.tags
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "worker-osdisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "worker-vm-${count.index}"
    admin_username = "azureuser"
    admin_password = "P@$$w0rd1234"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = file("~/.ssh/acloudguru.pub")
    }
  }

  depends_on = [azurerm_public_ip.worker_public_ip]
}

resource "null_resource" "worker_vm_provisioner" {
  count = 2
  triggers = {
    public_ip_address = azurerm_public_ip.worker_public_ip[count.index].ip_address
  }

  provisioner "file" {
    source      = "~/.ssh/acloudguru"
    destination = "/home/azureuser/.ssh/acloudguru"
    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.worker_public_ip[count.index].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "  sudo mkdir -p /etc/rancher/rke2",
      "  sudo chown -R $(whoami):$(whoami) /etc/rancher/rke2",
      "  touch /etc/rancher/rke2/config.yaml",
      "  sudo chmod 600 /home/azureuser/.ssh/acloudguru",
      "  TOKEN=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/acloudguru azureuser@${var.public_ip_addresses[0]} 'echo $TOKEN')",
      "  echo $TOKEN",
      "  echo \"server: https://${var.vm_private_ips[0]}:9345\" | sudo tee -a /etc/rancher/rke2/config.yaml",
      "  echo \"token: $TOKEN\" | sudo tee -a /etc/rancher/rke2/config.yaml",
      "  echo \"token: $TOKEN\"",
      "  sudo curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_TYPE='agent' sh -",
      "  sudo systemctl enable rke2-agent.service",
      "  sudo systemctl start rke2-agent.service",
    ]


    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.worker_public_ip[count.index].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }
  depends_on = [azurerm_virtual_machine.worker_vm]
}
