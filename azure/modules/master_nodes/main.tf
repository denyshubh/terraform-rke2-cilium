
resource "azurerm_public_ip" "master_public_ip" {
  count               = 3
  name                = "master-pub3-ip-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
  domain_name_label   = "unique-pub3-master${count.index + 1}" # <-- Change this value
  tags                = var.tags
}

resource "azurerm_network_interface" "master_nic" {
  count               = 3
  name                = "master-nic-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "master-ipconfig-${count.index + 1}"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.master_public_ip[count.index].id
  }
}

resource "azurerm_virtual_machine" "master_vm" {
  count                            = 3
  name                             = "master-vm-${count.index + 1}"
  location                         = var.location
  resource_group_name              = var.resource_group_name
  network_interface_ids            = [azurerm_network_interface.master_nic[count.index].id]
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
    name              = "master-osdisk-${count.index + 1}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "master-vm-${count.index + 1}"
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

  depends_on = [azurerm_public_ip.master_public_ip]
}

resource "null_resource" "first_master_vm_provisioner" {

  triggers = {
    public_ip_address = azurerm_public_ip.master_public_ip[0].ip_address
  }

  # provisioner "local-exec" {
  #   command = "echo 'Waiting for SSH port to be open...'; sleep 300"
  # }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/rancher/rke2",
      "sudo chown -R $(whoami):$(whoami) /etc/rancher/rke2",
      "sudo mkdir -p /var/lib/rancher/rke2/server/manifests",
      "sudo chown -R $(whoami):$(whoami) /var/lib/rancher/rke2/server/manifests",
      "sudo mkdir -p ~/.kube"
    ]

    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.master_public_ip[0].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }

  provisioner "file" {
    source      = "~/.ssh/acloudguru"
    destination = "/home/azureuser/.ssh/acloudguru"
    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.master_public_ip[0].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/rke2_config.tpl", {
      dns1 = azurerm_public_ip.master_public_ip[0].fqdn,
      dns2 = azurerm_public_ip.master_public_ip[1].fqdn,
      dns3 = azurerm_public_ip.master_public_ip[2].fqdn
      ip1  = azurerm_public_ip.master_public_ip[0].ip_address,
      ip2  = azurerm_public_ip.master_public_ip[1].ip_address,
      ip3  = azurerm_public_ip.master_public_ip[2].ip_address,
    })

    destination = "/etc/rancher/rke2/config.yaml"

    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.master_public_ip[0].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }


  provisioner "file" {
    content     = templatefile("${path.module}/templates/rke2_cilium_config.tpl", { k8s_service_host = azurerm_public_ip.master_public_ip[0].ip_address })
    destination = "/var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml"

    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.master_public_ip[0].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "  sudo curl -sfL https://get.rke2.io | sudo sh -",
      "  sudo systemctl enable rke2-server.service",
      "  sudo systemctl start rke2-server.service",
      "  sleep 120", # Allow some time for the first server node to initialize and generate the token
      "  TOKEN=$(sudo cat /var/lib/rancher/rke2/server/node-token)",
      "  echo \"TOKEN=$TOKEN\" | sudo tee -a /etc/environment",
      "  sudo ln -s /etc/rancher/rke2/rke2.yaml ~/.kube/config",
    ]


    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.master_public_ip[0].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }

  depends_on = [azurerm_virtual_machine.master_vm]
}

resource "null_resource" "other_master_vm_provisioner" {
  count = 2
  triggers = {
    public_ip_address = azurerm_public_ip.master_public_ip[count.index + 1].ip_address
  }

  provisioner "file" {
    source      = "~/.ssh/acloudguru"
    destination = "/home/azureuser/.ssh/acloudguru"
    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.master_public_ip[count.index + 1].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/rancher/rke2",
      "sudo chown -R $(whoami):$(whoami) /etc/rancher/rke2",
      "sudo mkdir -p /var/lib/rancher/rke2/server/manifests",
      "sudo chown -R $(whoami):$(whoami) /var/lib/rancher/rke2/server/manifests",
    ]

    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.master_public_ip[count.index + 1].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/rke2_other_master_config.tpl", {
      dns1 = azurerm_public_ip.master_public_ip[0].fqdn,
      dns2 = azurerm_public_ip.master_public_ip[1].fqdn,
      dns3 = azurerm_public_ip.master_public_ip[2].fqdn
      ip1  = azurerm_public_ip.master_public_ip[0].ip_address,
      ip2  = azurerm_public_ip.master_public_ip[1].ip_address,
      ip3  = azurerm_public_ip.master_public_ip[2].ip_address,
    })
    destination = "/etc/rancher/rke2/config.yaml"

    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.master_public_ip[count.index + 1].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "  sudo chmod 600 /home/azureuser/.ssh/acloudguru",
      "  TOKEN=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/acloudguru azureuser@${azurerm_public_ip.master_public_ip[0].ip_address} 'echo $TOKEN')",
      "  echo $TOKEN",
      "  echo \"server: https://${azurerm_public_ip.master_public_ip[0].fqdn}:9345\" | sudo tee -a /etc/rancher/rke2/config.yaml",
      "  echo \"token: $TOKEN\" | sudo tee -a /etc/rancher/rke2/config.yaml",
      "  echo \"token: $TOKEN\"",
      "  sudo curl -sfL https://get.rke2.io | sudo sh -",
      "  sudo systemctl enable rke2-server.service",
      "  sudo systemctl start rke2-server.service",
    ]


    connection {
      type        = "ssh"
      user        = "azureuser"
      password    = "P@$$w0rd1234"
      host        = azurerm_public_ip.master_public_ip[count.index + 1].ip_address
      private_key = file("~/.ssh/acloudguru")
    }
  }
  depends_on = [null_resource.first_master_vm_provisioner]
}

output "public_ip_addresses" {
  value = azurerm_public_ip.master_public_ip.*.ip_address
}

output "vm_private_ips" {
  value = flatten([
    for nic in azurerm_network_interface.master_nic :
    nic.private_ip_address
  ])
}


