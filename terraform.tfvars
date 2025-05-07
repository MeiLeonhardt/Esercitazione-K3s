subscription_id = "subscriptio-id"
prefix          = "K3s"
vm_master = {
  "VM-master" = {
    vm_size = "Standard_B2s"
    image = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    tags = {
      Environment = "dev"
      Role        = "K3s"
    }
  }
}
admin_username = "azureadmin"
admin_password = "Set-your-password"
