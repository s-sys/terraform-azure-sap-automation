output "default_resource_group" {
  description = "Information about default resource group."
  value       = format("%s (Exists: %s), Location: %s", var.resource_group, var.rg_exists, var.location)
}

output "vm_instances" {
  description = "ID of VMs instances"
  value       = {
    for k, vm in azurerm_linux_virtual_machine.vm : k => vm.id
  }
}

output "vm_network_private_ip" {
  description = "Private IP of network interface of VMs"
  value       = {
    for k, interface in azurerm_network_interface.network_interface : k => interface.private_ip_address
  }
}

output "admin_username" {
  description = "Admin user for remote login."
  value       = var.admin_username
}

output "default_location" {
  description = "Locations for creation of objects."
  value       = local.location
}

output "default_storage_name" {
  description = "Storage account in use."
  value       = var.data_stg_account
}

output "vm_network_public_ip" {
  description = "Public IP of network interface of VMs"
  value       = {
    for k, vm in azurerm_public_ip.public_ip : k => vm.ip_address
  }
}

output "lb_ip_sap" {
  description = "IP of load balancer"
  value       = (
                  var.lb_create == true
                  ? (
                      var.lb_create_public_ip == true
                      ? [for k in azurerm_public_ip.lb_public_ip : format("%s => %s", k.name, k.ip_address)]
                      : [for k in azurerm_lb.lb[0].frontend_ip_configuration : format("%s => %s", k.name, k.private_ip_address)]
                    )
                  : null
                )
}

output "azuread_application_id_login" {
  description = "AzureAD application ID"
  value       = (
                  var.fencing_enabled == true
                    ? (var.fencing_app_exists == false
                      ? azuread_application.azuread_app[0].application_id
                      : data.azuread_application.azuread_app[0].application_id
                      )
                    : ""
                )
}

output "azuread_application_password" {
  description = "AzureAD application password"
  value       = (
                  var.fencing_enabled == true && var.fencing_app_exists == false
                  ? azuread_application_password.azuread_app_password[0].value
                  : "USE EXISTING PASSWORD"
                )
  sensitive   = true
}

output "azuread_resource_group" {
  description = "Resource Group used in Azure"
  value       = local.resource_group
}

output "azuread_application_tenant_id" {
  description = "AzureAD Tenant ID from application"
  value       = data.azurerm_subscription.current.tenant_id
}

output "azuread_application_subscription_id" {
  description = "AzureAD Subscription ID from application"
  value       = data.azurerm_subscription.current.subscription_id
}
