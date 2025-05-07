variable "subscription_id" {
  description = "ID della sottoscrizione Azure"
  type        = string
  sensitive   = true
}

variable "prefix" {
  default     = "string"
  description = "Prefisso della risorsa"
}

variable "vm_master" {
  type = map(object({
    vm_size = string
    image = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    tags = map(string)
  }))

  default = {
    "VM-master" = {
      vm_size = "Standard_B1s"
      image = {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "22_04-lts-gen2"
        version   = "latest"
      }
      tags = {
        Environment = "dev"
        Role        = "K3s"
      }
    }
  }
}

variable "admin_username" {
  description = "Username dell'amministratore"
  type        = string
  default     = "azureuser"

  validation {
    condition     = length(var.admin_username) >= 6 && length(var.admin_username) <= 20
    error_message = "Il nome utente deve essere compreso tra 6 e 20 caratteri."
  }
}

variable "admin_password" {
  description = "Password dell'amministratore per le macchine virtuali"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 12 && can(regex("[A-Z]", var.admin_password)) && can(regex("[a-z]", var.admin_password)) && can(regex("[0-9]", var.admin_password)) && can(regex("[!@#$%^&*()_+]", var.admin_password))
    error_message = "La password deve contenere almeno 12 caratteri, inclusi maiuscole, minuscole, numeri e caratteri speciali (!@#$%^&*()_+)."
  }
}
