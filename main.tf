#################
# Azure provider
#################
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  experiments = [module_variable_optional_attrs]
}


#####################
# Azure subscription
#####################
data "azurerm_subscription" "current" {
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id == "" ? null : var.subscription_id
  tenant_id       = var.tenant_id       == "" ? null : var.client_secret
  client_id       = var.client_id       == "" ? null : var.client_id
  client_secret   = var.client_secret   == "" ? null : var.client_secret
}


##################
# Local variables
##################
locals {
  os             = data.external.os.result.os
  resource_group = (
                     var.rg_exists == true 
                     ? data.azurerm_resource_group.resource_group[0].name
                     : azurerm_resource_group.resource_group[0].name
                   )    
  location       = (  
                     var.rg_exists == true 
                     ? data.azurerm_resource_group.resource_group[0].location
                     : var.location
                   )    
  subnet_name    = (  
                     var.subnet_exists == true 
                     ? data.azurerm_subnet.subnet[0].name
                     : azurerm_subnet.subnet[0].name
                   )    
  subnet_id      = (  
                     var.subnet_exists == true 
                     ? data.azurerm_subnet.subnet[0].id
                     : azurerm_subnet.subnet[0].id
                   )    

  # NSG
  nsg_size          = length(var.nsg_rules)
  nsg_priority_base = 1000 

  # Additional DVDs
  additional_dvds_list = try(
                           [tostring(var.additional_dvds)],
                           tolist(var.additional_dvds),
                         )
}


#########################
# Cloud-init definitions
#########################
data  "template_file" "config" {
  for_each = { 
               for vm in var.vms
                 : vm.name => vm
             }  
  template = file(each.value.cloudinit)

  vars = {
    vm_number                    = length(var.vms)
    vm_name                      = each.key
    vm_names                     = join(" ", [for k, v in var.vms: v.name])
    vm_ip                        = each.value.priv_ip_addr
    vm_ips                       = join(" ", [for k, v in var.vms: v.priv_ip_addr])
    vm_ip_network                = cidrhost(var.subnet_addr, 0)
    vm_swap_size                 = each.value.swap_size
    vm_os_registration           = each.value.os_registration
    vm_reg_code                  = each.value.reg_code
    vm_reg_email                 = each.value.reg_email
    vm_product_id                = each.value.product_id
    vm_saptune_solution          = each.value.saptune_solution
    vm_sap_instance              = each.value.sap_instance
    admin_password               = var.admin_password
    sap_media_stg_enabled        = var.sap_media_stg_enabled
    sap_media_stg_type           = var.sap_media_stg_type
    sap_media_stg_account        = var.sap_media_stg_account
    sap_media_local_mount        = var.sap_media_local_mount
    sap_media_stg_remote_path    = replace(var.sap_media_stg_remote_path, "/", "")
    sap_media_stg_access_key     = (
                                     var.sap_media_stg_enabled == true
                                     ? (var.sap_media_stg_exists == true
                                         ? var.sap_media_stg_access_key
                                         : azurerm_storage_account.stg_sap_media[0].primary_access_key
                                       )
                                     : ""
                                   )
    sap_media_local_add_fstab    = var.sap_media_local_add_fstab
    sap_media_pe_private_ip      = (
                                     var.sap_media_stg_enabled == true && var.sap_media_stg_pe_enabled == true
                                     ? (
                                         var.sap_media_stg_pe_exists == true
                                         ? data.azurerm_private_endpoint_connection.pe_stg_sap_media[0].private_service_connection[0].private_ip_address
                                         : azurerm_private_endpoint.pe_stg_sap_media[0].private_service_connection[0].private_ip_address
                                       )
                                     : ""
                                   )
    data_stg_enabled             = var.data_stg_enabled
    data_stg_account             = var.data_stg_account
    data_stg_remote_path         = replace(var.data_stg_remote_path, "/", "")
    data_stg_remote_clean        = var.data_stg_remote_clean
    data_stg_local_add_fstab     = var.data_stg_local_add_fstab
    data_stg_pe_private_ip       = (
                                     var.data_stg_enabled == true && var.data_stg_pe_enabled == true
                                     ? (
                                         var.data_stg_pe_exists == true
                                         ? data.azurerm_private_endpoint_connection.pe_stg_data[0].private_service_connection[0].private_ip_address
                                         : azurerm_private_endpoint.pe_stg_data[0].private_service_connection[0].private_ip_address
                                       )
                                     : ""
                                   )
    saptrans_stg_enabled         = var.saptrans_stg_enabled
    saptrans_stg_type            = var.saptrans_stg_type
    saptrans_stg_account         = var.saptrans_stg_account
    saptrans_stg_remote_path     = (
                                     var.saptrans_stg_type == "stga"
                                     ? replace(var.saptrans_stg_remote_path, "/", "")
                                     : var.saptrans_stg_remote_path
                                   )
    saptrans_stg_remote_clean    = var.saptrans_stg_remote_clean
    saptrans_stg_local_add_fstab = var.saptrans_stg_local_add_fstab
    saptrans_stg_pe_private_ip   = (
                                     var.saptrans_stg_enabled == true && var.saptrans_stg_pe_enabled == true
                                     ? (
                                         var.saptrans_stg_pe_exists == true
                                         ? data.azurerm_private_endpoint_connection.pe_stg_saptrans[0].private_service_connection[0].private_ip_address
                                         : azurerm_private_endpoint.pe_stg_saptrans[0].private_service_connection[0].private_ip_address
                                       )
                                     : ""
                                   )
    enable_monitoring            = var.enable_monitoring
    cluster_install              = var.cluster_install
    cluster_unicast              = var.cluster_unicast
    cluster_password             = var.cluster_password
    subscription_id              = data.azurerm_subscription.current.subscription_id
    resource_group               = local.resource_group
    tenant_id                    = data.azurerm_subscription.current.tenant_id
    login_id                     = (
                                     var.fencing_enabled == true
                                     ? (var.fencing_app_exists == false
                                       ? azuread_application.azuread_app[0].application_id
                                       : data.azuread_application.azuread_app[0].application_id
                                       )
                                     : ""
                                   )
    app_password                 = (
                                     var.fencing_enabled == true
                                     ? (var.fencing_app_exists == false
                                       ? azuread_application_password.azuread_app_password[0].value
                                       : var.fencing_app_secret
                                       )
                                     : ""
                                   )
    sap_ascs_instance_sid        = var.sap_ascs_instance_sid
    sap_ascs_instance_id         = var.sap_ascs_instance_id
    sap_ascs_root_user           = var.sap_ascs_root_user
    sap_ascs_root_password       = var.sap_ascs_root_password
    sap_ascs_vip_address         = var.sap_ascs_vip_address
    sap_ascs_vip_hostname        = var.sap_ascs_vip_hostname
    sap_ers_instance_sid         = var.sap_ers_instance_sid
    sap_ers_instance_id          = var.sap_ers_instance_id
    sap_ers_root_user            = var.sap_ers_root_user
    sap_ers_root_password        = var.sap_ers_root_password
    sap_ers_vip_address          = var.sap_ers_vip_address
    sap_ers_vip_hostname         = var.sap_ers_vip_hostname
    sid_adm_password             = var.sid_adm_password
    sap_adm_password             = var.sap_adm_password
    master_password              = var.master_password
    sapmnt_path                  = var.sapmnt_path
    sidadm_user_uid              = var.sidadm_user_uid
    sidadm_user_gid              = var.sidadm_user_gid
    swpm_folder                  = var.swpm_folder
    sapexe_folder                = var.sapexe_folder
    sapmnt_inst_media            = var.sapmnt_inst_media
    additional_dvds              = join(" ", [for path in local.additional_dvds_list : tostring(path)])
    sap_hana_host                = var.sap_hana_host
    sap_hana_ip                  = var.sap_hana_ip
    sap_hana_sid                 = var.sap_hana_sid 
    sap_hana_instance            = var.sap_hana_instance
    sap_hana_password            = var.sap_hana_password
  }
}

data "template_cloudinit_config" "config" {
  for_each      = { 
                    for vm in var.vms
                      : vm.name => vm
                  }  
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.config[each.key].rendered
  }
}


################################
# Azure instance resource group
################################
data "azurerm_resource_group" "resource_group" {
  count = var.rg_exists == true ? 1 : 0
  name  = var.resource_group
}

resource "azurerm_resource_group" "resource_group" {
  count    = var.rg_exists == false ? 1 : 0
  name     = var.resource_group
  location = local.location
  tags     = var.tags
}


#############
# Azure vnet
#############
data "azurerm_virtual_network" "virtual_network" {
  count               = var.vnet_exists == true ? 1 : 0
  name                = var.vnet_name
  resource_group_name = var.vnet_rg
}


# Create virtual network
resource "azurerm_virtual_network" "virtual_network" {
  count               = var.vnet_exists == false ? 1 : 0
  name                = var.vnet_name
  address_space       = [var.vnet_addr]
  location            = local.location
  resource_group_name = (
                          var.resource_group == var.vnet_rg
                          ? (
                              var.rg_exists == true
                              ? data.azurerm_resource_group.resource_group[0].name
                              : azurerm_resource_group.resource_group[0].name
                            )
                          : var.vnet_rg
                        )
  tags                = var.tags
}


# Use existing subnet network
data "azurerm_subnet" "subnet" {
  count                = var.subnet_exists == true ? 1 : 0
  name                 = var.subnet_name
  resource_group_name  = (
                           var.vnet_exists == true
                           ? data.azurerm_virtual_network.virtual_network[0].resource_group_name
                           : azurerm_virtual_network.virtual_network[0].resource_group_name
                         )
  virtual_network_name = (
                           var.vnet_exists == true
                           ? data.azurerm_virtual_network.virtual_network[0].name
                           : azurerm_virtual_network.virtual_network[0].name
                         )
}


# Create subnet
resource "azurerm_subnet" "subnet" {
  count                = var.subnet_exists == false ? 1 : 0
  name                 = var.subnet_name
  resource_group_name  = (
                           var.vnet_exists == true
                           ? data.azurerm_virtual_network.virtual_network[0].resource_group_name
                           : azurerm_virtual_network.virtual_network[0].resource_group_name
                         )
  virtual_network_name = ( 
                           var.vnet_exists == true
                           ? data.azurerm_virtual_network.virtual_network[0].name
                           : azurerm_virtual_network.virtual_network[0].name
                         )
  address_prefixes     = [var.subnet_addr]
  service_endpoints    = ["Microsoft.Storage"]
  enforce_private_link_endpoint_network_policies = true
  enforce_private_link_service_network_policies  = true
}


######################
# AzureAD Application
######################
data "azuread_client_config" "current" {
  count = var.fencing_enabled == true && var.fencing_app_exists == false ? 1 : 0
}

resource "random_uuid" "fencing_app_oauth2_permission_scope" {
  count = var.fencing_enabled == true && var.fencing_app_exists == false ? 1 : 0
}

resource "random_uuid" "fencing_app_app_role" {
  count = var.fencing_enabled == true && var.fencing_app_exists == false ? 1 : 0
}

data "azuread_application" "azuread_app" {
  count        = var.fencing_enabled == true && var.fencing_app_exists == true ? 1 : 0
  display_name = var.fencing_app_name
}

resource "azuread_application" "azuread_app" {
  count        = var.fencing_enabled == true && var.fencing_app_exists == false ? 1 : 0
  display_name = var.fencing_app_name
  owners       = [data.azuread_client_config.current[0].object_id]

  api {
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to fence VMs on behalf of the signed-in user."
      admin_consent_display_name = var.fencing_app_name
      enabled                    = true
      id                         = random_uuid.fencing_app_oauth2_permission_scope[0].result
      type                       = "User"
      user_consent_description   = "Allow the application to fence VMs on your behalf."
      user_consent_display_name  = var.fencing_app_name
      value                      = "user_impersonation"
    }
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "Role to fence VMs"
    display_name         = format("%s_app_role", var.fencing_app_name)
    value                = format("%s_app_role", var.fencing_app_name)
    id                   = random_uuid.fencing_app_app_role[0].result
    enabled              = true
  }
}

data "azuread_service_principal" "azuread_service_principal" {
  count          = var.fencing_enabled == true && var.fencing_app_exists == true ? 1 : 0
  application_id = data.azuread_application.azuread_app[0].application_id
}

resource "azuread_service_principal" "azuread_service_principal" {
  count                        = var.fencing_enabled == true && var.fencing_app_exists == false ? 1 : 0
  application_id               = azuread_application.azuread_app[0].application_id
  app_role_assignment_required = false
}

resource "random_password" "azuread_rnd_password" {
  count   = var.fencing_enabled == true && var.fencing_app_exists == false ? 1 : 0
  length  = 42
  special = false

  keepers = {
      resource_group = local.resource_group
  }
}

# Create random password for AzureAD Application
resource "azuread_application_password" "azuread_app_password" {
  count                 = var.fencing_enabled == true && var.fencing_app_exists == false ? 1 : 0
  application_object_id = azuread_application.azuread_app[0].id
  end_date              = "2030-01-01T01:01:01Z"
}

# Create role definition for AzureAD Application
resource "azurerm_role_definition" "vm_role_definition" {
  count             = var.fencing_enabled == true && var.fencing_app_exists == false ? 1 : 0
  name              = format("%s_role_definition", var.fencing_app_name)
  scope             = (
                        var.rg_exists == true
                        ? data.azurerm_resource_group.resource_group[0].id
                        : azurerm_resource_group.resource_group[0].id
                      )
  description       = "This role allows AzureAD Application to fence VMs in Azure"
  assignable_scopes = [(
                         var.rg_exists == true
                         ? data.azurerm_resource_group.resource_group[0].id
                         : azurerm_resource_group.resource_group[0].id
                      )]

  permissions {
    actions     = ["Microsoft.Compute/*/read",
                   "Microsoft.Compute/virtualMachines/powerOff/action",
                   "Microsoft.Compute/virtualMachines/start/action",
                   "Microsoft.Compute/virtualMachines/restart/action"]
    not_actions = []

  }
}

# Set permissions for the AzureAD Application in the VMs
resource "azurerm_role_assignment" "role_assign_vm_fencing_on_instance" {
  for_each            = { 
                          for vm in var.vms
                            : vm.name => vm
                              if var.fencing_enabled == true && var.fencing_app_exists == false && var.fencing_perms_rg == false
                        }  
  # Scope based on virtual machines only
  scope              = azurerm_linux_virtual_machine.vm[each.key].id
  role_definition_id = azurerm_role_definition.vm_role_definition[0].role_definition_resource_id
  principal_id       = (
                         var.fencing_app_exists == false
                         ? azuread_service_principal.azuread_service_principal[0].object_id
                         : data.azuread_service_principal.azuread_service_principal[0].object_id
                       )
}

# Set permissions for the AzureAD Application in the resource group
resource "azurerm_role_assignment" "role_assign_vm_fencing_on_rg" {
  for_each            = { 
                          for vm in var.vms
                            : vm.name => vm
                              if var.fencing_enabled == true && var.fencing_app_exists == false && var.fencing_perms_rg == true
                        }  
  # Scope based on resource group permission
  scope              = (
                         var.rg_exists == true
                         ? data.azurerm_resource_group.resource_group[0].id
                         : azurerm_resource_group.resource_group[0].id
                       )
  role_definition_id = azurerm_role_definition.vm_role_definition[0].role_definition_resource_id
  principal_id       = (
                         var.fencing_app_exists == false
                         ? azuread_service_principal.azuread_service_principal[0].object_id
                         : data.azuread_service_principal.azuread_service_principal[0].object_id
                       )
}


#######################
# Public IP addressses
#######################
resource "azurerm_public_ip" "public_ip" {
  for_each            = { 
                          for vm in var.vms
                            : vm.name => vm
                              if vm.add_pub_ip == true
                        }   
  name                = format("%s_public_ip", each.key)
  location            = local.location
  resource_group_name = local.resource_group
  allocation_method   = ( 
                          each.value.pub_ip_persist == true
                          ? "Static"
                          : "Dynamic"
                        )
  sku                 = (
                          lower(var.lb_sku) != "basic"
                          ? var.lb_sku
                          : "Basic"
                        )
  tags                = var.tags
}


############################
# Load Balancer for cluster
############################
# Create public IPs for Load Balancer
resource "azurerm_public_ip" "lb_public_ip" {
  for_each            = { 
                          for frontend in var.lb_frontend_ip
                            : frontend.name => frontend
                              if var.lb_create == true && var.lb_create_public_ip == true
                        }   
  name                = format("%s_public_ip", each.key)
  location            = local.location
  resource_group_name = local.resource_group
  allocation_method   = (
                          lower(var.lb_sku) == "basic"
                          ? "Dynamic"
                          : "Static"
                        )
  sku                 = var.lb_sku
  tags                = var.tags
}

# Create load balancer
resource "azurerm_lb" "lb" {
  count               = var.lb_create == true ? 1 : 0
  name                = var.lb_name
  location            = local.location
  resource_group_name = local.resource_group
  sku                 = var.lb_sku
  tags                = var.tags

  dynamic "frontend_ip_configuration" {
    for_each = var.lb_frontend_ip
    content {
    name                          = format("%s_frontend_config", frontend_ip_configuration.value.name)
    subnet_id                     = (
                                      var.lb_create_public_ip == true
                                      ? null
                                      : (
                                          var.subnet_exists == true
                                          ? data.azurerm_subnet.subnet[0].id
                                          : azurerm_subnet.subnet[0].id
                                        )
                                    )
    private_ip_address_allocation = (
                                    var.lb_create_public_ip == true
                                    ? null
                                    : (
                                        frontend_ip_configuration.value.private_ip == ""
                                        ? "Dynamic"
                                        : "Static"
                                      )
                                    )
    private_ip_address            = (
                                    var.lb_create_public_ip == true
                                    ? null
                                    : (
                                        frontend_ip_configuration.value.private_ip == ""
                                        ? null
                                        : frontend_ip_configuration.value.private_ip
                                      )
                                    )
    public_ip_address_id          = (
                                      var.lb_create_public_ip == true
                                      ? azurerm_public_ip.lb_public_ip[frontend_ip_configuration.value.name].id
                                      : null
                                    )
    }
  }
}

# Create load balancer backend address pool
resource "azurerm_lb_backend_address_pool" "lb_bap" {
  count           = var.lb_create == true ? 1 : 0
  name            = format("%s_backend_address_pool", var.lb_name)
  loadbalancer_id = azurerm_lb.lb[0].id
}

resource "azurerm_network_interface_backend_address_pool_association" "lb_network_interface" {
  for_each                = {
                              for vm in var.vms
                                : vm.name => vm
                                  if var.lb_create == true
                            }
  ip_configuration_name   = azurerm_network_interface.network_interface[each.key].ip_configuration[0].name
  network_interface_id    = azurerm_network_interface.network_interface[each.key].id
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_bap[0].id
}

# Load balance probe rules
resource "azurerm_lb_probe" "lb_probe" {
  for_each            = {
                          for rule in var.lb_probe_rules
                            : rule.name => rule
                              if var.lb_create == true
                        }
  name                = format("lb_probe_%s", each.key)
  loadbalancer_id     = azurerm_lb.lb[0].id
  protocol            = each.value.protocol
  request_path        = (
                          lower(each.value.protocol) == "http" || lower(each.value.protocol) == "https"
                          ? (
                              each.value.request_path == null
                              ? "/"
                              : each.value.request_path
                            )
                          : null
                        )
  port                = each.value.port
  interval_in_seconds = each.value.interval
  number_of_probes    = each.value.number_of_probes
}

# Load balance rules
resource "azurerm_lb_rule" "lb_rule" {
  for_each                       = {
                                     for rule in var.lb_rules
                                       : rule.name => rule
                                         if var.lb_create == true
                                   }
  name                           = format("lb_rule_%s", each.key)
  loadbalancer_id                = azurerm_lb.lb[0].id
  frontend_ip_configuration_name = format("%s_frontend_config", each.value.frontend_name)
  probe_id                       = azurerm_lb_probe.lb_probe[each.value.probe_name].id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_bap[0].id]
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  enable_floating_ip             = each.value.enable_floating_ip
  idle_timeout_in_minutes        = each.value.idle_timeout_in_minutes
  load_distribution              = each.value.load_distribution
  enable_tcp_reset               = (
                                     lower(var.lb_sku) == "standard"
                                     ? each.value.enable_tcp_reset
                                     : false
                                   )
  disable_outbound_snat          = each.value.disable_outbound_snat
}

# # Output rule for load balancer
# # Confliting when instance use public IP
# resource "azurerm_lb_outbound_rule" "lb_outbound_rule" {
#   count                   = var.lb_create == true && var.lb_create_public_ip == true ? 1 : 0
#   loadbalancer_id         = azurerm_lb.lb[0].id
#   name                    = "Outbound_All"
#   protocol                = "All"
#   backend_address_pool_id = azurerm_lb_backend_address_pool.lb_bap[0].id
#   resource_group_name     = local.resource_group
# 
#   frontend_ip_configuration {
#     name = azurerm_lb.lb[0].frontend_ip_configuration[0].name
#   }
# }


#############################
# Load Balancer for outbound
#############################
# Create public IP for Load Balancer
resource "azurerm_public_ip" "lb_out_public_ip" {
  count               = var.lb_out_create == true ? 1 : 0
  name                = format("%s_public_ip", var.lb_out_name)
  location            = local.location
  resource_group_name = local.resource_group
  allocation_method   = (
                          lower(var.lb_out_sku) == "basic"
                          ? "Dynamic"
                          : "Static"
                        )
  sku                 = var.lb_out_sku
  tags                = var.tags
}

# Create load balancer
resource "azurerm_lb" "lb_out" {
  count               = var.lb_out_create == true ? 1 : 0
  name                = var.lb_out_name
  location            = local.location
  resource_group_name = local.resource_group
  sku                 = var.lb_out_sku
  tags                = var.tags

  frontend_ip_configuration {
    name                 = format("%s_frontend_config", var.lb_out_name)
    public_ip_address_id = azurerm_public_ip.lb_out_public_ip[0].id
  }
}

# Create load balancer backend address pool
resource "azurerm_lb_backend_address_pool" "lb_out_bap" {
  count           = var.lb_out_create == true ? 1 : 0
  name            = format("%s_backend_address_pool", var.lb_out_name)
  loadbalancer_id = azurerm_lb.lb_out[0].id
}

resource "azurerm_network_interface_backend_address_pool_association" "lb_out_network_interface" {
  for_each                = {
                              for vm in var.vms
                                : vm.name => vm
                                  if var.lb_out_create == true && vm.add_pub_ip == false
                            }
  ip_configuration_name   = azurerm_network_interface.network_interface[each.key].ip_configuration[0].name
  network_interface_id    = azurerm_network_interface.network_interface[each.key].id
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_out_bap[0].id
}

# Output rule for load balancer
resource "azurerm_lb_outbound_rule" "lb_out_rule" {
  count                   = var.lb_out_create == true ? 1 : 0
  loadbalancer_id         = azurerm_lb.lb_out[0].id
  name                    = "Outbound_All"
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_out_bap[0].id

  frontend_ip_configuration {
    name = azurerm_lb.lb_out[0].frontend_ip_configuration[0].name
  }
}


##############
# NAT Gateway
##############
data "azurerm_resource_group" "nat_gw_rg" {
  count = var.nat_gateway_enabled == true && var.nat_gateway_exists == true ? 1 : 0
  name  = var.nat_gateway_rg
}

resource "azurerm_public_ip" "nat_gw_pub_ip" {
  count               = var.nat_gateway_enabled == true && var.nat_gateway_exists == false ? 1 : 0
  name                = format("%s_public_ip", var.nat_gateway_name)
  location            = local.location
  resource_group_name = (
                          var.rg_exists == true
                          ? data.azurerm_resource_group.resource_group[0].name
                          : azurerm_resource_group.resource_group[0].name
                        )
  allocation_method   = (
                          var.nat_gateway_pub_ip_persist == true
                          ? "Static"
                          : "Dynamic"
                        )
  sku                 = (
                          lower(var.nat_gateway_sku) != "basic"
                          ? var.nat_gateway_sku
                          : "Basic"
                        )
  tags                = var.tags
}

resource "azurerm_public_ip_prefix" "nat_gw_pub_ip_prefix" {
  count               = var.nat_gateway_enabled == true && var.nat_gateway_exists == false ? 1 : 0
  name                = format("%s_public_ip_prefix", var.nat_gateway_name)
  location            = local.location
  resource_group_name = (
                          var.rg_exists == true
                          ? data.azurerm_resource_group.resource_group[0].name
                          : azurerm_resource_group.resource_group[0].name
                        )
  prefix_length       = 31
  tags                = var.tags
}

data "azurerm_nat_gateway" "nat_gateway" {
  count               = var.nat_gateway_enabled == true && var.nat_gateway_exists == true ? 1 : 0
  name                = var.nat_gateway_name
  resource_group_name = data.azurerm_resource_group.nat_gw_rg[0].name
}

resource "azurerm_nat_gateway" "nat_gateway" {
  count                   = var.nat_gateway_enabled == true && var.nat_gateway_exists == false ? 1 : 0
  name                    = var.nat_gateway_name
  location                = local.location
  resource_group_name     = (
                              var.rg_exists == true
                              ? data.azurerm_resource_group.resource_group[0].name
                              : azurerm_resource_group.resource_group[0].name
                            )
  sku_name                = (
                              lower(var.nat_gateway_sku) != "basic"
                              ? var.nat_gateway_sku
                              : "Basic"
                            )
  idle_timeout_in_minutes = (
                              var.nat_gateway_idle_timeout == 0
                              ? 5
                              : var.nat_gateway_idle_timeout
                            )
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_gw_pub_ip_assoc" {
  count                = var.nat_gateway_enabled == true && var.nat_gateway_exists == false ? 1 : 0
  nat_gateway_id       = (
                           var.nat_gateway_exists == true
                           ? data.azurerm_nat_gateway.nat_gateway[0].id
                           : azurerm_nat_gateway.nat_gateway[0].id
                         )
  public_ip_address_id = (
                           var.nat_gateway_exists == true
                           ? data.azurerm_nat_gateway.nat_gateway[0].public_ip_address_ids[0] 
                           : azurerm_public_ip.nat_gw_pub_ip[0].id
                         )
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "nat_gw_pub_ip_prefix_assoc" {
  count               = var.nat_gateway_enabled == true && var.nat_gateway_exists == false ? 1 : 0
  nat_gateway_id      = (  
                           var.nat_gateway_exists == true 
                           ? data.azurerm_nat_gateway.nat_gateway[0].id
                           : azurerm_nat_gateway.nat_gateway[0].id
                         )
  public_ip_prefix_id = (
                           var.nat_gateway_exists == true
                           ? data.azurerm_nat_gateway.nat_gateway[0].public_ip_prefix_ids[0]
                           : azurerm_public_ip_prefix.nat_gw_pub_ip_prefix[0].id
                         )
}

resource "azurerm_subnet_nat_gateway_association" "nat_gw_subnet_assoc" {
  count          = var.nat_gateway_enabled == true && var.nat_gateway_exists == false ? 1 : 0
  subnet_id      = (
                     var.subnet_exists == true
                     ? data.azurerm_subnet.subnet[0].id
                     : azurerm_subnet.subnet[0].id
                   )
  nat_gateway_id = (  
                     var.nat_gateway_exists == true
                     ? data.azurerm_nat_gateway.nat_gateway[0].id
                     : azurerm_nat_gateway.nat_gateway[0].id
                   )
}


#########################
# Network security group
#########################
data "azurerm_resource_group" "nsg" {
  count = var.nsg_enabled == true && var.nsg_exists == true ? 1 : 0
  name  = var.nsg_rg
}

data "azurerm_network_security_group" "nsg" {
  count               = var.nsg_enabled == true && var.nsg_exists == true ? 1 : 0 
  name                = var.nsg_name
  resource_group_name = data.azurerm_resource_group.nsg[0].name
}

resource "azurerm_network_security_group" "nsg" {
  count               = var.nsg_enabled == true && var.nsg_exists == false ? 1 : 0
  name                = var.nsg_name
  location            = local.location
  resource_group_name = (
                          var.nsg_rg == ""
                          ? local.resource_group
                          : var.nsg_rg
                        )
  tags                = var.tags
}

# Create Network Security rules
resource "azurerm_network_security_rule" "nsg_rule" {
  for_each                    = {
                                  for nsg_rule in var.nsg_rules
                                    : nsg_rule.name => nsg_rule
                                      if var.nsg_enabled == true && nsg_rule.enabled == true
                                }
  name                        = each.key
  priority                    = local.nsg_priority_base + index(var.nsg_rules.*.name, each.key) + 1
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = (
                                  var.nsg_exists == true
                                  ? data.azurerm_resource_group.nsg[0].name
                                  : (
                                      var.nsg_rg == ""
                                      ? local.resource_group
                                      : var.nsg_rg
                                    )
                                )
  network_security_group_name = (
                                  var.nsg_exists == true
                                  ? data.azurerm_network_security_group.nsg[0].name
                                  : azurerm_network_security_group.nsg[0].name
                                )
}


#####################
# Network interfaces
#####################
resource "azurerm_network_interface" "network_interface" {
  for_each                      = {
                                    for vm in var.vms
                                      : vm.name => vm
                                  }
  name                          = format("%s_nic_%s", each.key, 1)
  location                      = local.location
  resource_group_name           = local.resource_group
  enable_accelerated_networking = each.value.net_accel
  tags                          = var.tags

  ip_configuration {
    name                          = format("%s_nic_config", each.key)
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = (
                                      each.value.priv_ip_dynamic == true
                                      ? "Dynamic"
                                      : "Static"
                                    )
    private_ip_address            = (
                                      each.value.priv_ip_dynamic == true
                                      ? null
                                      : each.value.priv_ip_addr
                                    )
    public_ip_address_id          = (
                                      each.value.add_pub_ip == true
                                      ? azurerm_public_ip.public_ip[each.key].id
                                      : null
                                    )
  }
}

resource "azurerm_network_interface_security_group_association" "network_nsg_association" {
  for_each                  = {
                                for vm in var.vms
                                  : vm.name => vm
                                    if var.nsg_enabled == true
                              }
  network_interface_id      = azurerm_network_interface.network_interface[each.key].id
  network_security_group_id = (
                                var.nsg_exists == true
                                ? data.azurerm_network_security_group.nsg[0].id
                                : azurerm_network_security_group.nsg[0].id
                              )
}


################################
# Storage account for SAP media
################################
data "azurerm_resource_group" "rg_sap_media" {
  count = var.sap_media_stg_enabled == true ? 1 : 0
  name  = var.sap_media_stg_rg
}

data "azurerm_storage_account" "stg_sap_media" {
  count               = var.sap_media_stg_enabled == true && var.sap_media_stg_exists == true ? 1 : 0
  name                = var.sap_media_stg_account
  resource_group_name = data.azurerm_resource_group.rg_sap_media[0].name
}

data "http" "stg_sap_media_get_pub_ip" {
  count = var.sap_media_stg_enabled == true && var.sap_media_stg_exists == false ? 1 : 0
  url   = "https://ifconfig.me/ip"
}

resource "azurerm_storage_account" "stg_sap_media" {
  count                     = var.sap_media_stg_enabled == true && var.sap_media_stg_exists == false ? 1 : 0
  name                      = var.sap_media_stg_account
  resource_group_name       = data.azurerm_resource_group.rg_sap_media[0].name
  location                  = data.azurerm_resource_group.rg_sap_media[0].location
  account_tier              = var.sap_media_stg_tier
  account_replication_type  = var.sap_media_stg_repl
  account_kind              = var.sap_media_stg_account_kind
  enable_https_traffic_only = (
                                var.sap_media_stg_type == "nfsv4"
                                ? false
                                : true
                              )
  is_hns_enabled            = (
                                var.sap_media_stg_type == "nfsv3"
                                ? true
                                : false
                              )
  nfsv3_enabled             = (
                                var.sap_media_stg_type == "nfsv3"
                                ? true
                                : false
                              )
  tags                      = var.tags
}

# Adding network_rules in a existing storage account is not supported
# https://github.com/hashicorp/terraform-provider-azurerm/issues/13640
resource "azurerm_storage_account_network_rules" "stg_sap_media_network_rules" {
  count                      = var.sap_media_stg_enabled == true && var.sap_media_stg_exists == false ? 1 : 0
  storage_account_id         = azurerm_storage_account.stg_sap_media[0].id
  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  ip_rules                   = [chomp(data.http.stg_sap_media_get_pub_ip[0].body)]
  virtual_network_subnet_ids = [(
                                  var.subnet_exists == true
                                  ? data.azurerm_subnet.subnet[0].id
                                  : azurerm_subnet.subnet[0].id
                               )]
}

# Use a existing private endpoint for SAP Media
data "azurerm_private_endpoint_connection" "pe_stg_sap_media" {
  count               = var.sap_media_stg_enabled == true && var.sap_media_stg_pe_enabled == true && var.sap_media_stg_pe_exists == true ? 1 : 0
  name                = (
                          var.sap_media_stg_pe_name == ""
                          ? format("pe_stg_sap_media_%s", var.sap_media_stg_account)
                          : var.sap_media_stg_pe_name
                        )
  resource_group_name = data.azurerm_resource_group.rg_sap_media[0].name
}

# Create private endpoint for SAP Media network access to NFSv4
resource "azurerm_private_endpoint" "pe_stg_sap_media" {
  count               = var.sap_media_stg_enabled == true && var.sap_media_stg_pe_enabled == true && var.sap_media_stg_pe_exists == false ? 1 : 0
  name                = (
                          var.sap_media_stg_pe_name == ""
                          ? format("pe_stg_sap_media_%s", var.sap_media_stg_account)
                          : var.sap_media_stg_pe_name
                        )
  resource_group_name = data.azurerm_resource_group.rg_sap_media[0].name
  location            = data.azurerm_resource_group.rg_sap_media[0].location
  subnet_id           = (
                          var.subnet_exists == true
                          ? data.azurerm_subnet.subnet[0].id
                          : azurerm_subnet.subnet[0].id
                        )
  tags                = var.tags

  private_service_connection {
    name                           = (
                                       var.sap_media_stg_pe_name == ""
                                       ? format("psc_pe_stg_sap_media_%s", var.sap_media_stg_account)
                                       : format("psc_%s", var.sap_media_stg_pe_name)
                                     )
    is_manual_connection           = false
    private_connection_resource_id = (
                                       var.sap_media_stg_exists == true
                                       ? data.azurerm_storage_account.stg_sap_media[0].id
                                       : azurerm_storage_account.stg_sap_media[0].id
                                     )
    subresource_names              = ["file"]
  }
}

# Create share in Azure Storage for NFSv4
resource "azurerm_storage_share" "stg_sap_media_share_nfsv4" {
  count                = var.sap_media_stg_enabled == true && var.sap_media_stg_exists == false && var.sap_media_stg_type == "nfsv4" ? 1 : 0
  name                 = replace(var.sap_media_stg_remote_path, "/", "")
  storage_account_name = azurerm_storage_account.stg_sap_media[0].name
  enabled_protocol     = "NFS"
  quota                = 100
}

# Create share in Azure Storage for CIFS/NFSv3
resource "azurerm_storage_share" "stg_sap_media_share_smb" {
  count                = var.sap_media_stg_enabled == true && var.sap_media_stg_exists == false && (var.sap_media_stg_type == "nfsv3" || var.sap_media_stg_type == "smb") ? 1 : 0
  name                 = replace(var.sap_media_stg_remote_path, "/", "")
  storage_account_name = azurerm_storage_account.stg_sap_media[0].name
  enabled_protocol     = "SMB"
  quota                = 50
}


###############################
# Storage account for SAP data
###############################
data "azurerm_resource_group" "rg_stg_data" {
  count = var.data_stg_enabled == true ? 1 : 0
  name  = var.data_stg_rg
}

data "azurerm_storage_account" "stg_data" {
  count               = var.data_stg_enabled == true && var.data_stg_exists == true ? 1 : 0
  name                = var.data_stg_account
  resource_group_name = data.azurerm_resource_group.rg_stg_data[0].name
}

data "http" "stg_data_get_pub_ip" {
  count = var.data_stg_enabled == true && var.data_stg_exists == false ? 1 : 0
  url   = "https://ifconfig.me/ip"
}

resource "azurerm_storage_account" "stg_data" {
  count                     = var.data_stg_enabled == true && var.data_stg_exists == false ? 1 : 0
  name                      = var.data_stg_account
  resource_group_name       = data.azurerm_resource_group.rg_stg_data[0].name
  location                  = data.azurerm_resource_group.rg_stg_data[0].location
  account_tier              = var.data_stg_tier
  account_replication_type  = var.data_stg_repl
  account_kind              = var.data_stg_account_kind
  enable_https_traffic_only = false
  tags                      = var.tags
}

# Adding network_rules in a existing storage account is not supported
# https://github.com/hashicorp/terraform-provider-azurerm/issues/13640
resource "azurerm_storage_account_network_rules" "stg_data_network_rules" {
  count                      = var.data_stg_enabled == true && var.data_stg_exists == false ? 1 : 0
  storage_account_id         = azurerm_storage_account.stg_data[0].id
  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  ip_rules                   = [chomp(data.http.stg_data_get_pub_ip[0].body)]
  virtual_network_subnet_ids = [(
                                  var.subnet_exists == true
                                  ? data.azurerm_subnet.subnet[0].id
                                  : azurerm_subnet.subnet[0].id
                               )]
}

# Use a existing private endpoint for SAP Data
data "azurerm_private_endpoint_connection" "pe_stg_data" {
  count               = var.data_stg_enabled == true && var.data_stg_pe_enabled == true && var.data_stg_pe_exists == true ? 1 : 0
  name                = (
                          var.data_stg_pe_name == ""
                          ? format("pe_stg_data_%s", var.data_stg_account)
                          : var.data_stg_pe_name
                        )
  resource_group_name = data.azurerm_resource_group.rg_stg_data[0].name
}

# Rules to allow private endpoint for SAP data network access to NFSv4
resource "azurerm_private_endpoint" "pe_stg_data" {
  count               = var.data_stg_enabled == true && var.data_stg_pe_enabled == true && var.data_stg_pe_exists == false ? 1 : 0
  name                = (
                          var.data_stg_pe_name == ""
                          ? format("pe_stg_data_%s", var.data_stg_account)
                          : var.data_stg_pe_name
                        )
  resource_group_name = data.azurerm_resource_group.rg_stg_data[0].name
  location            = data.azurerm_resource_group.rg_stg_data[0].location
  subnet_id           = (
                          var.subnet_exists == true
                          ? data.azurerm_subnet.subnet[0].id
                          : azurerm_subnet.subnet[0].id
                        )
  tags                = var.tags

  private_service_connection {
    name                           = (
                                       var.data_stg_pe_name == ""
                                       ? format("psc_pe_stg_data_%s", var.data_stg_account)
                                       : format("psc_%s", var.data_stg_pe_name)
                                     )
    is_manual_connection           = false
    private_connection_resource_id = (
                                       var.data_stg_exists == true
                                       ? data.azurerm_storage_account.stg_data[0].id
                                       : azurerm_storage_account.stg_data[0].id
                                     )
    subresource_names              = ["file"]
  }
}

# Create share in Azure Storage
resource "azurerm_storage_share" "stg_data_share" {
  count                = var.data_stg_enabled == true && var.data_stg_exists == false ? 1 : 0
  name                 = replace(var.data_stg_remote_path, "/", "")
  storage_account_name = azurerm_storage_account.stg_data[0].name
  enabled_protocol     = "NFS"
  quota                = 100
}


###################################
# Storage account for SAP saptrans
###################################
data "azurerm_resource_group" "rg_stg_saptrans" {
  count = var.saptrans_stg_enabled == true ? 1 : 0
  name  = var.saptrans_stg_rg
}

data "azurerm_storage_account" "stg_saptrans" {
  count               = var.saptrans_stg_enabled == true && var.saptrans_stg_exists == true && var.saptrans_stg_type == "stga" ? 1 : 0
  name                = var.saptrans_stg_account
  resource_group_name = data.azurerm_resource_group.rg_stg_saptrans[0].name
}

data "http" "stg_saptrans_get_pub_ip" {
  count = var.saptrans_stg_enabled == true && var.saptrans_stg_exists == false && var.saptrans_stg_type == "stga" ? 1 : 0
  url   = "https://ifconfig.me/ip"
}

resource "azurerm_storage_account" "stg_saptrans" {
  count                     = var.saptrans_stg_enabled == true && var.saptrans_stg_exists == false && var.saptrans_stg_type == "stga" ? 1 : 0
  name                      = var.saptrans_stg_account
  resource_group_name       = data.azurerm_resource_group.rg_stg_saptrans[0].name
  location                  = data.azurerm_resource_group.rg_stg_saptrans[0].location
  account_tier              = var.saptrans_stg_tier
  account_replication_type  = var.saptrans_stg_repl
  account_kind              = var.saptrans_stg_account_kind
  enable_https_traffic_only = false
  tags                      = var.tags
}

# Adding network_rules in a existing storage account is not supported
# https://github.com/hashicorp/terraform-provider-azurerm/issues/13640
resource "azurerm_storage_account_network_rules" "stg_saptrans_network_rules" {
  count                      = var.saptrans_stg_enabled == true && var.saptrans_stg_exists == false ? 1 : 0
  storage_account_id         = azurerm_storage_account.stg_saptrans[0].id
  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  ip_rules                   = [chomp(data.http.stg_saptrans_get_pub_ip[0].body)]
  virtual_network_subnet_ids = [(
                                  var.subnet_exists == true
                                  ? data.azurerm_subnet.subnet[0].id
                                  : azurerm_subnet.subnet[0].id
                               )]
}

# Use a existing private endpoint for SAP Data
data "azurerm_private_endpoint_connection" "pe_stg_saptrans" {
  count               = var.saptrans_stg_enabled == true && var.saptrans_stg_pe_enabled == true && var.saptrans_stg_pe_exists == true ? 1 : 0
  name                = (
                          var.saptrans_stg_pe_name == ""
                          ? format("pe_stg_saptrans_%s", var.saptrans_stg_account)
                          : var.saptrans_stg_pe_name
                        )
  resource_group_name = data.azurerm_resource_group.rg_stg_saptrans[0].name
}

# Rules to allow private endpoint for SAP trans network access to NFS
resource "azurerm_private_endpoint" "pe_stg_saptrans" {
  count               = var.saptrans_stg_enabled == true && var.saptrans_stg_pe_enabled == true && var.saptrans_stg_pe_exists == false ? 1 : 0
  name                = (
                          var.saptrans_stg_pe_name == ""
                          ? format("pe_stg_saptrans_%s", var.saptrans_stg_account)
                          : var.saptrans_stg_pe_name
                        )
  resource_group_name = data.azurerm_resource_group.rg_stg_saptrans[0].name
  location            = data.azurerm_resource_group.rg_stg_saptrans[0].location
  subnet_id           = (
                          var.subnet_exists == true
                          ? data.azurerm_subnet.subnet[0].id
                          : azurerm_subnet.subnet[0].id
                        )
  tags                = var.tags

  private_service_connection {
    name                           = (
                                       var.saptrans_stg_pe_name == ""
                                       ? format("psc_pe_stg_saptrans_%s", var.saptrans_stg_account)
                                       : format("psc_%s", var.saptrans_stg_pe_name)
                                     )
    is_manual_connection           = false
    private_connection_resource_id = (
                                       var.saptrans_stg_exists == true
                                       ? data.azurerm_storage_account.stg_saptrans[0].id
                                       : azurerm_storage_account.stg_saptrans[0].id
                                     )
    subresource_names              = ["file"]
  }
}

# Create share for saptrans in Azure Storage
resource "azurerm_storage_share" "stg_saptrans_share" {
  count                = var.saptrans_stg_enabled == true && var.saptrans_stg_exists == false && var.saptrans_stg_type == "stga" ? 1 : 0
  name                 = replace(var.saptrans_stg_remote_path, "/", "")
  storage_account_name = azurerm_storage_account.stg_saptrans[0].name
  enabled_protocol     = "NFS"
  quota                = 100
}


################################
# Storage account for instances
################################
data "azurerm_resource_group" "rg_stg_vm_data" {
  name  = var.vm_data_stg_rg
}

data "azurerm_storage_account" "stg_vm_data" {
  count               = var.vm_data_stg_exists == true ? 1 : 0
  name                = var.vm_data_stg_account
  resource_group_name = data.azurerm_resource_group.rg_stg_vm_data.name
}

resource "azurerm_storage_account" "stg_vm_data" {
  count                    = var.vm_data_stg_exists == false ? 1 : 0
  name                     = var.vm_data_stg_account
  resource_group_name      = data.azurerm_resource_group.rg_stg_vm_data.name
  location                 = local.location
  account_tier             = var.vm_data_stg_tier
  account_replication_type = var.vm_data_stg_repl
  account_kind             = var.vm_data_stg_account_kind
  tags                     = var.tags
}


#######################################
# Storage account for Boot diagnostics
#######################################
data "azurerm_resource_group" "rg_boot_diag" {
  name  = var.boot_diag_stg_rg
}

data "azurerm_storage_account" "stg_boot_diag" {
  count               = var.boot_diag_stg_enabled == true && var.boot_diag_stg_exists == true ? 1 : 0
  name                = var.boot_diag_stg_account
  resource_group_name = data.azurerm_resource_group.rg_boot_diag.name
}

resource "azurerm_storage_account" "stg_boot_diag" {
  count                    = var.boot_diag_stg_enabled == true && var.boot_diag_stg_exists == false ? 1 : 0
  name                     = var.boot_diag_stg_account
  resource_group_name      = data.azurerm_resource_group.rg_boot_diag.name
  location                 = local.location
  account_tier             = var.boot_diag_stg_tier
  account_replication_type = var.boot_diag_stg_repl
  account_kind             = var.boot_diag_stg_account_kind
  tags                     = var.tags
}


##################
# Placement group
##################
data "azurerm_proximity_placement_group" "proximity_pg" {
  count               = var.proximity_pg_enabled == true && var.proximity_pg_exists == true ? 1 : 0
  name                = var.proximity_pg_name
  resource_group_name = var.proximity_pg_rg
}

resource "azurerm_proximity_placement_group" "proximity_pg" {
  count               = var.proximity_pg_enabled == true && var.proximity_pg_exists == false ? 1 : 0
  name                = var.proximity_pg_name
  location            = local.location
  resource_group_name = (
                          var.proximity_pg_rg == ""
                          ? local.resource_group
                          : var.proximity_pg_rg
                        )
  tags                = var.tags
}


###################
# Availability set
###################
resource "azurerm_availability_set" "avail_set" {
  count                        = var.availability_set_enabled == true ? 1 : 0
  name                         = var.availability_set_name
  location                     = local.location
  resource_group_name          = local.resource_group
  proximity_placement_group_id = (
                                   var.proximity_pg_enabled == true
                                   ? (
                                       var.proximity_pg_exists == true
                                       ? data.azurerm_proximity_placement_group.proximity_pg[0].id
                                       : azurerm_proximity_placement_group.proximity_pg[0].id
                                     )
                                   : null
                                 )
  tags                         = var.tags
}


###############
# NetApp Files
###############
data "azurerm_netapp_account" "account" {
  count               = var.netapp_files_enabled == true && var.netapp_files_exists == true ? 1 : 0
  name                = var.netapp_account_name
  resource_group_name = var.netapp_files_rg
}


resource "azurerm_netapp_account" "account" {
  count               = var.netapp_files_enabled == true && var.netapp_files_exists == false ? 1 : 0
  name                = var.netapp_account_name
  resource_group_name = (
                          var.netapp_files_rg == ""
                          ? local.resource_group
                          : var.netapp_files_rg
                        )
  location            = local.location
  tags                = var.tags
}


data "azurerm_netapp_pool" "pool" {
  count               = var.netapp_files_enabled == true && var.netapp_pool_exists == true ? 1 : 0
  name                = var.netapp_pool_name
  resource_group_name = var.netapp_files_rg
  account_name        = var.netapp_account_name
}


resource "azurerm_netapp_pool" "pool" {
  count               = var.netapp_files_enabled == true && var.netapp_pool_exists == false ? 1 : 0
  name                = var.netapp_pool_name
  account_name        = var.netapp_account_name
  resource_group_name = var.netapp_files_rg
  location            = local.location
  service_level       = var.netapp_pool_service_level
  size_in_tb          = var.netapp_pool_size
  tags                = var.tags
}


data "azurerm_netapp_volume" "volume" {
  count               = var.netapp_files_enabled == true && var.netapp_volume_exists == true ? 1 : 0
  account_name        = var.netapp_account_name
  pool_name           = var.netapp_pool_name
  resource_group_name = var.netapp_files_rg
  name                = var.netapp_volume_name
}


resource "azurerm_netapp_volume" "volume" {
  count               = var.netapp_files_enabled == true && var.netapp_volume_exists == false ? 1 : 0
  name                = var.netapp_volume_name
  resource_group_name = var.netapp_files_rg
  location            = local.location
  account_name        = var.netapp_account_name
  pool_name           = var.netapp_pool_name
  volume_path         = var.netapp_volume_path
  service_level       = var.netapp_volume_service_level
  subnet_id           = local.subnet_id
  protocols           = var.netapp_volume_protocols
  storage_quota_in_gb = var.netapp_volume_quota_in_gb
  tags                = var.tags

  lifecycle {
    prevent_destroy = true
  }
}


#################################
# Extra disk for virtual machine
#################################
resource "azurerm_managed_disk" "vm_extra_disk" {
  for_each             = {
                           for vm in var.vms
                             : vm.name => vm
                               if vm.add_extra_disk == true
                         }
  name                 = format("%s_data_disk1", each.value.name)
  location             = (
                           var.vm_data_stg_exists == true
                           ? data.azurerm_storage_account.stg_vm_data[0].location
                           : azurerm_storage_account.stg_vm_data[0].location
                         )
  resource_group_name  = (
                           var.vm_data_stg_exists == true
                           ? data.azurerm_storage_account.stg_vm_data[0].resource_group_name
                           : azurerm_storage_account.stg_vm_data[0].resource_group_name
                         )
  storage_account_type = each.value.disk_type
  create_option        = "Empty"
  disk_size_gb         = each.value.extra_disk_size_gb
  tags                 = var.tags
}


# Attach extra disk for virtual machine
resource "azurerm_virtual_machine_data_disk_attachment" "attach_vm_extra_disk" {
  for_each           = {
                         for vm in var.vms
                           : vm.name => vm
                             if vm.add_extra_disk == true
                       }
  managed_disk_id    = azurerm_managed_disk.vm_extra_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[each.key].id
  lun                = 1
  caching            = "ReadWrite"
}


##################
# Virtual machine
##################
data "external" "os" {
  working_dir = format("%s", path.module)
  program     = ["printf", "{\"os\": \"Linux\"}"]
}

resource "tls_private_key" "ssh" {
  count     = local.os == "Windows" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each                        = {
                                      for vm in var.vms
                                        : vm.name => vm
                                    }
  name                            = each.key
  location                        = local.location
  resource_group_name             = (
                                      var.rg_exists == true
                                      ? data.azurerm_resource_group.resource_group[0].name
                                      : azurerm_resource_group.resource_group[0].name
                                    )
  network_interface_ids           = [azurerm_network_interface.network_interface[each.key].id]
  size                            = each.value.size
  custom_data                     = data.template_cloudinit_config.config[each.key].rendered
  computer_name                   = each.key
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  availability_set_id             = (
                                      var.availability_set_enabled
                                      ? azurerm_availability_set.avail_set[0].id
                                      : null
                                    )
  proximity_placement_group_id    = (
                                      var.proximity_pg_enabled == true
                                      ? (
                                          var.proximity_pg_exists == true
                                          ? data.azurerm_proximity_placement_group.proximity_pg[0].id
                                          : azurerm_proximity_placement_group.proximity_pg[0].id
                                        )
                                      : null
                                    )
  tags                            = var.tags

  os_disk {
    name                 = format("%s_os_disk", each.key)
    caching              = "ReadWrite"
    storage_account_type = each.value.disk_type
  }

  source_image_reference {
    publisher = each.value.image.publisher
    offer     = each.value.image.offer
    sku       = each.value.image.sku
    version   = each.value.image.version
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = (
                   local.os == "Linux"
                   ? file("~/.ssh/id_rsa.pub")
                   : tls_private_key.ssh[0].public_key_openssh
                 )
  }

  boot_diagnostics {
    storage_account_uri = (
                            each.value.add_boot_diag == true
                            ? (var.boot_diag_stg_enabled == true
                              ? (var.boot_diag_stg_exists == true
                                ? data.azurerm_storage_account.stg_boot_diag[0].primary_blob_endpoint
                                : azurerm_storage_account.stg_boot_diag[0].primary_blob_endpoint
                                )
                              : null
                              )
                            : null
                          )
  }
}
