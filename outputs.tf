output "subnet_id" {
  value       = azurerm_subnet.subnet_master.id
  description = "Id della subnet-master"
}

output "subnet_CIDR" {
  value       = azurerm_subnet.subnet_master.address_prefixes[0]
  description = "CIDR della subnet-master"
}

output "Public_ip" {
  value       = azurerm_public_ip.k3s_ip.ip_address
  description = "Indirizzo IP pubblico della VM"
}
