####################
# Azure environment
####################
variable "subscription_id" {
  description = "Subscriptions ID to be used."
  type        = string
  default     = ""
}

variable "client_id" {
  description = "Client ID from Azure."
  type        = string
  default     = ""
}

variable "client_secret" {
  description = "Client secret from Azure."
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Tenant ID from Azure."
  type        = string
  default     = ""
}


##################
# Azure resources
##################
variable "rg_exists" {
  description = "Set if resource group exists or should be created."
  type        = bool
  default     = false
}

variable "resource_group" {
  description = "Resource group name to create."
  type        = string
  default     = "rg-sap"
}

variable "location" {
  description = "Location where resources should be created."
  type        = string
  default     = "eastus"
}


################
# Azure network
################
variable "vnet_exists" {
  description = "Set if vnet exists to decide to use an existent or create a new one."
  type        = bool
  default     = true
}

variable "vnet_name" {
  description = "Name of virtual network."
  type        = string
  default     = "vnet"
}

variable "vnet_addr" {
  description = "Network address for virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vnet_rg" {
  description = "Vnet's resource group."
  type        = string
  default     = "rg-vnet"
}

variable "subnet_exists" {
  description = "Set if subnet exists to decide to use an existent or create a new one."
  type        = bool
  default     = true
}

variable "subnet_name" {
  description = "Name of virtual subnet."
  type        = string
  default     = "subnet"
}

variable "subnet_addr" {
  description = "Network address Name of virtual subnet."
  type        = string
  default     = "10.0.1.0/24"
}


###################
# User information
###################
variable "admin_username" {
  description = "Name for the admin user."
  type        = string
  default     = "azureroot"
}

variable "admin_password" {
  description = "Password for admin user."
  type        = string
  default     = "Passw0rd"
}


###################
# Availability set
###################
variable "availability_set_enabled" {
  description = "Set if Availability set should be used or not."
  type        = bool
  default     = false
}

variable "availability_set_name" {
  description = "Availability set name."
  type        = string
  default     = "availability_set"
}


############################
# Proximity placement group
############################
variable "proximity_pg_enabled" {
  description = "Set if proximity placement group should be used or not."
  type        = bool
  default     = false
}

variable "proximity_pg_exists" {
  description = "Set if proximity placement group exists or one should be created."
  type        = bool
  default     = false
}

variable "proximity_pg_name" {
  description = "Proximity placement group name."
  type        = string
  default     = "proximity_placement_group"
}

variable "proximity_pg_rg" {
  description = "Resource group of Proximity placement group."
  type        = string
  default     = ""
}


########################
# Storage for SAP Media
########################
variable "sap_media_stg_enabled" {
  description = "Set if storage for SAP Media should be enabled or not."
  type        = bool
  default     = false
}

variable "sap_media_stg_type" {
  description = "Set storage type to create for SAP Media."
  type        = string
  default     = "nfsv4"

  validation {
    condition     = contains(["nfsv3", "nfsv4", "smb"], var.sap_media_stg_type)
    error_message = "Storage type SAP media not supported."
  }
}

variable "sap_media_stg_exists" {
  description = "Set if storage account for SAP Media exists or if one should be created."
  type        = bool
  default     = true
}

variable "sap_media_stg_account" {
  description = "Storage account for SAP Media."
  type        = string
  default     = "storagesapmedia"

  validation {
    condition     = can(regex("[0-9a-z]{3,24}", var.sap_media_stg_account))
    error_message = "Storage account name for SAP media not matching rules from Azure."
  }
}

variable "sap_media_stg_rg" {
  description = "Storage account's resource group for SAP Media."
  type        = string
  default     = "rg-sap-media"
}

variable "sap_media_stg_tier" {
  description = "Tier to create storage account for SAP Media."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.sap_media_stg_tier)
    error_message = "SAP media tier not supported."
  }
}

variable "sap_media_stg_repl" {
  description = "Storage replication type to create storage account for SAP Media."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.sap_media_stg_repl)
    error_message = "SAP media replication type not supported."
  }
}

variable "sap_media_stg_account_kind" {
  description = "Kind of storage to create storage account for SAP Media."
  type        = string
  default     = "StorageV2"

  validation {
    condition     = contains(["BlobStorage", "BlockBlobStorage", "FileStorage", "Storage", "StorageV2"], var.sap_media_stg_account_kind)
    error_message = "SAP media account kind not supported."
  }
}

variable "sap_media_stg_access_key" {
  description = "Access key to access storage account for SAP media."
  type        = string
  default     = ""
}

variable "sap_media_stg_remote_path" {
  description = "Path for SAP media in storage account."
  type        = string
  default     = "/sapmedia"
}

variable "sap_media_local_mount" {
  description = "Path for mounting SAP media on server."
  type        = string
  default     = "/mnt/sapmedia"
}

variable "sap_media_local_add_fstab" {
  description = "Add SAP media entry to /etc/fstab file."
  type        = bool
  default     = false
}

variable "sap_media_stg_pe_enabled" {
  description = "Set if private endpoint should be enabled or not for SAP Media storage account."
  type        = bool
  default     = false
}

variable "sap_media_stg_pe_exists" {
  description = "Set if private endpoint exists or one should be created."
  type        = bool
  default     = false
}

variable "sap_media_stg_pe_name" {
  description = "Set private endpoint name for SAP Media storage account."
  type        = string
  default     = ""
}


###################################
# Storage for SAP Application data
###################################
variable "data_stg_enabled" {
  description = "Set if storage for SAP data should be enabled or not."
  type        = bool
  default     = false
}

variable "data_stg_exists" {
  description = "Set if storage account for data exists or if one should be created."
  type        = bool
  default     = true
}

variable "data_stg_account" {
  description = "Storage account for SAP data."
  type        = string
  default     = "stgdata"

  validation {
    condition     = can(regex("[0-9a-z]{3,24}", var.data_stg_account))
    error_message = "Storage account name for SAP data not matching rules from Azure."
  }
}

variable "data_stg_rg" {
  description = "Storage account's resource group for SAP data."
  type        = string
  default     = "rg-data"
}

variable "data_stg_tier" {
  description = "Tier to create storage account for SAP data."
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Premium"], var.data_stg_tier)
    error_message = "SAP data supported only in Premium storage accounts."
  }
}

variable "data_stg_repl" {
  description = "Storage replication type to create storage account for SAP data."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.data_stg_repl)
    error_message = "SAP data replication type not supported."
  }
}

variable "data_stg_account_kind" {
  description = "Kind of storage to create storage account for SAP data."
  type        = string
  default     = "FileStorage"

  validation {
    condition     = contains(["FileStorage"], var.data_stg_account_kind)
    error_message = "SAP data support for NFS 4.1 available only in FileStorage."
  }
}

variable "data_stg_remote_path" {
  description = "Path in storage account where data for SAP is found."
  type        = string
  default     = "/sapecp"

  validation {
    condition     = try( 
                      length(regex("^\\/[[:alnum:]]+", var.data_stg_remote_path)) > 2
                    )    
    error_message = "SAP data remote path not formatted properly."
  }
}

variable "data_stg_remote_clean" {
  description = "Set if remote path on NFS should be cleared or not."
  type        = bool
  default     = true
}

variable "data_stg_local_add_fstab" {
  description = "Add SAP NFS entry to /etc/fstab file."
  type        = bool
  default     = true
}

variable "data_stg_pe_enabled" {
  description = "Set if private endpoint should be created in the storage account."
  type        = bool
  default     = false
}

variable "data_stg_pe_exists" {
  description = "Set if private endpoint exists or one should be created."
  type        = bool
  default     = false
}

variable "data_stg_pe_name" {
  description = "Set name of private endpoint."
  type        = string
  default     = ""
}


#############################
# Storage for SAP trans data
#############################
variable "saptrans_stg_enabled" {
  description = "Set if storage for SAP trans should be enabled or not."
  type        = bool
  default     = false
}


variable "saptrans_stg_type" {
  description = "Set storage type for usage with SAP saptrans."
  type        = string
  default     = "stga"

  validation {
    condition     = contains(["stga", "nfs"], var.saptrans_stg_type)
    error_message = "SAP saptrans data supported only with Azure Storage Account or NFS share."
  }
}

variable "saptrans_stg_exists" {
  description = "Set if storage account for saptrans exists or if one should be created."
  type        = bool
  default     = true
}

variable "saptrans_stg_account" {
  description = "Storage account for SAP saptrans data."
  type        = string
  default     = "stgsaptrans"

  validation { 
    condition     = can(regex("[0-9a-z]{3,24}", var.saptrans_stg_account))
    error_message = "Storage account name for saptrans not matching rules from Azure."
  }
}

variable "saptrans_stg_rg" {
  description = "Storage account's resource group for SAP saptrans data."
  type        = string
  default     = "rg-saptrans"
}

variable "saptrans_stg_tier" {
  description = "Tier to create storage account for SAP saptrans data."
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Premium"], var.saptrans_stg_tier)
    error_message = "SAP saptrans data supported only in Premium storage accounts."
  }
}

variable "saptrans_stg_repl" {
  description = "Storage replication type to create storage account for SAP saptrans data."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.saptrans_stg_repl)
    error_message = "SAP trans replication type not supported."
  }
}

variable "saptrans_stg_account_kind" {
  description = "Kind of storage to create storage account for SAP saptrans data."
  type        = string
  default     = "FileStorage"

  validation {
    condition     = contains(["FileStorage"], var.saptrans_stg_account_kind)
    error_message = "SAP trans account kind not supported."
  }
}

variable "saptrans_stg_access_key" {
  description = "Access key to access storage account for SAP saptrans data."
  type        = string
  default     = ""
}

variable "saptrans_stg_remote_path" {
  description = "Path in storage account where data for SAP saptrans is found."
  type        = string
  default     = "/sapecp"

#   validation {
#     condition     = try(
#                       length(regex("^\\/[[:alnum:]]+", var.saptrans_stg_remote_path)) > 2,
#                       length(regex("^[[:alnum:]]:\\(\\/[[:alnum:]]\\)+", var.saptrans_stg_remote_path)) > 10
#                     )
#     error_message = "SAP trans remote path not formatted properly."
#   }
}

variable "saptrans_stg_remote_clean" {
  description = "Set if remote path on NFS should be cleared or not."
  type        = bool
  default     = true
}

variable "saptrans_stg_local_add_fstab" {
  description = "Add SAP saptrans NFS entry to /etc/fstab file."
  type        = bool
  default     = true
}

variable "saptrans_stg_pe_enabled" {
  description = "Set if private endpoint should be created in the storage account for SAP trans."
  type        = bool
  default     = false
}

variable "saptrans_stg_pe_exists" {
  description = "Set if private endpoint exists or one should be created for the storage account for SAP trans."
  type        = bool
  default     = false
}

variable "saptrans_stg_pe_name" {
  description = "Set name for private endpoint of the storage account for SAP trans."
  type        = string
  default     = ""
}


########################
# Storage for instances
########################
variable "vm_data_stg_exists" {
  description = "Set if storage account for data exists or if one should be created."
  type        = bool
  default     = false
}

variable "vm_data_stg_account" {
  description = "Storage account for instances."
  type        = string
  default     = "stgvmdata"

  validation {
    condition     = can(regex("[0-9a-z]{3,24}", var.vm_data_stg_account))
    error_message = "Storage account name for instances not matching rules from Azure."
  }
}

variable "vm_data_stg_rg" {
  description = "Storage account's resource group for instances."
  type        = string
  default     = "rg-vm"
}

variable "vm_data_stg_tier" {
  description = "Tier to create storage account for instances."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.vm_data_stg_tier)
    error_message = "Storage account tier type for instances not supported."
  }
}

variable "vm_data_stg_repl" {
  description = "Storage replication type to create storage account for instances."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.vm_data_stg_repl)
    error_message = "Storage account replication type for instances not supported."
  }
}

variable "vm_data_stg_account_kind" {
  description = "Kind of storage to create storage account for instances."
  type        = string
  default     = "StorageV2"

  validation {
    condition     = contains(["BlobStorage", "BlockBlobStorage", "FileStorage", "Storage", "StorageV2"], var.vm_data_stg_account_kind)
    error_message = "Storage account kind for instances not supported."
  }
}


###################
# Boot diagnostics
###################
variable "boot_diag_stg_enabled" {
  description = "Set if storage account for boot diagnostics should be enabled or not."
  type        = bool
  default     = false
}

variable "boot_diag_stg_exists" {
  description = "Set if storage account exists and should be used or not exists and should be created."
  type        = bool
  default     = true
}

variable "boot_diag_stg_account" {
  description = "Storage account for boot diagnostics."
  type        = string
  default     = "storage"

  validation {
    condition     = can(regex("[0-9a-z]{3,24}", var.boot_diag_stg_account))
    error_message = "Storage account name not matching rules from Azure."
  }
}

variable "boot_diag_stg_rg" {
  description = "Storage account's resource group for boot diagnostics."
  type        = string
  default     = "rg-boot-diag"
}

variable "boot_diag_stg_tier" {
  description = "Tier used for storage account used in boot diagnostics."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.boot_diag_stg_tier)
    error_message = "Storage account tier type for boot diagnostics not supported."
  }
}

variable "boot_diag_stg_repl" {
  description = "Storage replication type to create storage account."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.boot_diag_stg_repl)
    error_message = "Storage account replication type for boot diagnostics not supported."
  }
}

variable "boot_diag_stg_account_kind" {
  description = "Storage account kind for boot diagnostics."
  type        = string
  default     = "StorageV2"

  validation {
    condition     = contains(["BlobStorage", "BlockBlobStorage", "FileStorage", "Storage", "StorageV2"], var.boot_diag_stg_account_kind)
    error_message = "Storage account kind for boot diagnostics not supported."
  }
}


######
# VMs
######
variable "vms" {
  description = "List of VMs to create"
  type             = list(object({
    name           = string
    size           = string
    image          = object({
      publisher    = string
      offer        = string
      sku          = string
      version      = string
    })
    add_pub_ip         = bool
    pub_ip_persist     = bool
    add_boot_diag      = bool
    priv_ip_dynamic    = bool
    priv_ip_addr       = string
    disk_type          = string
    disk_size_gb       = number
    add_extra_disk     = bool
    extra_disk_size_gb = number
    net_accel          = bool
    cloudinit          = string
    swap_size          = number
    os_registration    = bool
    reg_code           = string
    reg_email          = string
    product_id         = string
    saptune_solution   = string
    sap_instance       = string
    })
  )
}


#########################
# Network security group
#########################
variable "nsg_enabled" {
  description = "Set if NSG should be used or not."
  type        = bool
  default     = true
}

variable "nsg_exists" {
  description = "Set if NSG exists and should be used or a new one should be created."
  type        = bool
  default     = false
}

variable "nsg_name" {
  description = "Network security group name."
  type        = string
  default     = ""
}

variable "nsg_rg" {
  description = "Network security group's resource group."
  type        = string
  default     = ""
}

variable "nsg_rules" {
  description = "Network security group rules."
  type                         = list(object({
    name                       = string
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
    enabled                    = bool
    })
  )

  validation {
    condition     = alltrue([
      for rule in var.nsg_rules : contains(["Inbound", "Outbound"], rule.direction)
      ])
    error_message = "Directing rule not supported."
  }

  validation {
    condition     = alltrue([
      for rule in var.nsg_rules : contains(["Allow", "Deny"], rule.access)
      ])
    error_message = "Access type not supported."
  }

  validation {
    condition     = alltrue([
      for rule in var.nsg_rules: contains(["Tcp", "Udp", "Icmp", "Esp", "Ah", "*"], rule.protocol)
      ])
    error_message = "Protocol not supported."
  }

  validation {
    condition     = alltrue([
      for rule in var.nsg_rules: try(rule.source_port_range == "*",
        tonumber(element(rule.source_port_range, 0)) <= 65535)
      ])
    error_message = "Invalid source port range."
  }

  validation {
    condition     = alltrue([
      for rule in var.nsg_rules: try(rule.destination_port_range == "*",
        tonumber(rule.destination_port_range) <= 65535)
      ])
    error_message = "Invalid destination port range."
  }
}


############################
# Load balancer for cluster
############################
variable "lb_create" {
  description = "Set if load balancer should be created."
  type        = bool
  default     = false
}

variable "lb_create_public_ip" {
  description = "Set if public IP should be attached to the load balancer."
  type        = bool
  default     = false
}

variable "lb_name" {
  description = "Set Load Balancer name."
  type        = string
  default     = "my-lb"
}

variable "lb_sku" {
  description = "Set LB SKU to use."
  type        = string
  default     = "Basic"
}

variable "lb_frontend_ip" {
  description  = "Load balancer frontend IP."
  type         = list(object({
    name       = string
    private_ip = string
    })
  )
  default      = [{
    name       = "lb"
    private_ip = "10.0.0.1"
  }]
}

variable "lb_probe_rules" {
  description        = "Load balancer probe rules."
  type               = list(object({
    name             = string
    port             = number
    protocol         = string
    request_path     = optional(string)
    interval         = number
    number_of_probes = number
    })
  )

  default            = [{
    name             = ""
    port             = 0
    protocol         = "Tcp"   
    interval         = 5       
    number_of_probes = 2       
  }]

  validation {
    condition     = alltrue([
      for rule in var.lb_probe_rules: try(tonumber(rule.port) <= 65535)
      ])
    error_message = "Invalid port number."
  }

  validation {
    condition     = alltrue([
      for rule in var.lb_probe_rules: contains(["Http", "Https", "Tcp"], rule.protocol)
      ])
    error_message = "Protocol not supported."
  }

  validation {
    condition     = alltrue([
      for rule in var.lb_probe_rules: rule.interval >= 5
      ])
    error_message = "Interval out of range."
  }

  validation {
    condition     = alltrue([
      for rule in var.lb_probe_rules: rule.number_of_probes >= 1
      ])
    error_message = "Number of probes out of range."
  }
}


variable "lb_rules" {
  description = "Load balancing rules."
  type                      = list(object({
    name                    = string
    frontend_name           = string
    probe_name              = string
    protocol                = string
    frontend_port           = number
    backend_port            = number
    enable_floating_ip      = bool
    idle_timeout_in_minutes = number
    load_distribution       = string
    enable_tcp_reset        = bool
    disable_outbound_snat   = bool
    })
  )

  default                   = [{
    name                    = "rule01"
    frontend_name           = "frontend"
    probe_name              = "name"
    protocol                = "Tcp"
    frontend_port           = 1000
    backend_port            = 1000
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  }]

  validation {
    condition     = alltrue([
      for rule in var.lb_rules: contains(["Tcp", "Udp", "All"], rule.protocol)
      ])
    error_message = "Protocol not supported."
  }

  validation {
    condition     = alltrue([
      for rule in var.lb_rules: try(rule.frontend_port < 65535)
      ])
    error_message = "Invalid port number range."
  }

  validation {
    condition     = alltrue([
      for rule in var.lb_rules: try(rule.backend_port <= 65535)
      ])
    error_message = "Invalid port number range."
  }

  validation {
    condition     = alltrue([
      for rule in var.lb_rules: try(rule.idle_timeout_in_minutes >= 4 && rule.idle_timeout_in_minutes <= 30)
      ])
    error_message = "Invalid timeout range in minutes."
  }


  validation {
    condition     = alltrue([
      for rule in var.lb_rules: contains(["Default", "SourceIP", "SourceIPProtocol"], rule.load_distribution)
      ])
    error_message = "Load distribution not supported."
  }
}


#############################
# Load Balancer for Outbound
#############################
variable "lb_out_create" {
  description = "Set if Load Balancer for Outbound should be created or not."
  type        = bool
  default     = false
}

variable "lb_out_name" {
  description = "Set name for Load Balancer used for outbound."
  type        = string
  default     = "lb_outbound"
}

variable "lb_out_sku" {
  description = "Set SKU for Load Balancer used for outbound."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard"], var.lb_out_sku)
    error_message = "SKU type not supported."
  }
}


##############
# NAT Gateway
##############
variable "nat_gateway_enabled" {
  description = "Set if NAT Gateway should be enabled or not in the subnet."
  type        = bool
  default     = false
}

variable "nat_gateway_exists" {
  description = "Set if a NAT Gateway already exists in the subnet."
  type        = bool
  default     = true
}

variable "nat_gateway_rg" {
  description = "Set NAT Gateway Resource Group name."
  type        = string
  default     = "nat-gw-rg"
}

variable "nat_gateway_name" {
  description = "Set NAT Gateway resource name."
  type        = string
  default     = "nat-gw"
}

variable "nat_gateway_pub_ip_persist" {
  description = "Set if public IP of NAT Gateway is going to be persistent or not."
  type        = bool
  default     = true
}

variable "nat_gateway_sku" {
  description = "Set SKU to be used for NAT Gateway and Public IP."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard"], var.nat_gateway_sku)
    error_message = "SKU type not supported."
  }
}

variable "nat_gateway_idle_timeout" {
  description = "Set NAT Gateway Idle timeout in minutes."
  type        = number
  default     = 10
}

variable "nat_gateway_zones" {
  description = "Set Availability Zones where NAT Gateway should be located."
  type        = list(string)
  default     = ["1"]
}


######################
# AzureAD fencing app
######################
variable "fencing_enabled" {
  description = "Set if fencing should be enabled or not."
  type        = bool
  default     = false
}

variable "fencing_app_exists" {
  description = "Set if fencing app exists or one should be created."
  type        = bool
  default     = true
}

variable "fencing_app_name" {
  description = "Set fencing application name."
  type        = string
  default     = "fencing_app"
}

variable "fencing_perms_rg" {
  description = "Set if fencing permission is based on resource group or VMs."
  type        = bool
  default     = false
}

variable "fencing_app_secret" {
  description = "Secret used for fencing app."
  type        = string
  default     = ""
  sensitive   = true
}


##########
# General
##########
variable "enable_monitoring" {
  description = "Set if monitoring should be enabled on nodes."
  type        = bool
  default     = false
}

variable "cluster_install" {
  description = "Set if HA cluster should be installed."
  type        = bool
  default     = false
}

variable "cluster_unicast" {
  description = "Set if unicast should be used in the cluster."
  type        = bool
  default     = true
}

variable "cluster_password" {
  description = "Set password used for cluster user."
  type        = string
  default     = "Passw0rd"
}


###############
# NetApp files
###############
variable "netapp_files_enabled" {
  description = "Set if NetApp files should be enabled."
  type        = bool
  default     = false
}

variable "netapp_files_exists" {
  description = "Set if NetApp files already exists or if one should be created."
  type        = bool
  default     = true
}

variable "netapp_files_rg" {
  description = "NetApp file's resource group."
  type        = string
  default     = "rg-netapp-files"
}

variable "netapp_account_name" {
  description = "Set NetApp account name for usage."
  type        = string
  default     = ""
}

variable "netapp_pool_exists" {
  description = "Set if NetApp files pool exists or not."
  type        = bool
  default     = false
}

variable "netapp_pool_name" {
  description = "Set NetApp pool name for usage."
  type        = string
  default     = ""
}

variable "netapp_pool_service_level" {
  description = "Set NetApp pool service level."
  type        = string
  default     = "Premium"
}

variable "netapp_pool_size" {
  description = "Set NetApp pool size in Terabytes."
  type        = number
  default     = 4
}

variable "netapp_volume_exists" {
  description = "Set if NetApp volume exists or not."
  type        = bool
  default     = false
}

variable "netapp_volume_name" {
  description = "Set NetApp volume name."
  type        = string
  default     = ""
}

variable "netapp_volume_path" {
  description = "Set NetApp volume path."
  type        = string
  default     = ""
}

variable "netapp_volume_service_level" {
  description = "Set NetApp volume service level."
  type        = string
  default     = "Premium"
}

variable "netapp_volume_protocols" {
  description = "Set NetApp volume protocols to use."
  type        = list
  default     = ["NFSv4.1"]
}

variable "netapp_volume_quota_in_gb" {
  description = "Set NetApp volume quota."
  type        = number
  default     = 500
}


###################
# SAP
###################
variable "sap_ascs_instance_sid" {
  description = "Set ASCS instance SID."
  type        = string
  default     = "NW1"
}

variable "sap_ascs_instance_id" {
  description = "Set ASCS instance ID."
  type        = string
  default     = "00"

  validation {
    condition     = length(var.sap_ascs_instance_id) == 2
    error_message = "ASCS Instance ID must have 2 chars."
  }
}

variable "sap_ascs_root_user" {
  description = "Set ASCS root user."
  type        = string
  default     = "root"
}

variable "sap_ascs_root_password" {
  description = "Set ASCS root password."
  type        = string
  default     = ""
}

variable "sap_ascs_vip_address" {
  description = "Set ASCS VIP address."
  type        = string
  default     = "10.0.0.1"
}

variable "sap_ascs_vip_hostname" {
  description = "Set VIP hostname used for ASCS cluster."
  type        = string
  default     = "ascs-vip"

  validation {
    condition     = length(var.sap_ascs_vip_hostname) <= 13
    error_message = "VIP hostname must not exceed 13 chars."
  }
}

# ERS
variable "sap_ers_instance_sid" {
  description = "Set ERS instance SID."
  type        = string
  default     = "ERS"
}

variable "sap_ers_instance_id" {
  description = "Set ERS instance ID."
  type        = string
  default     = "01"

  validation {
    condition     = length(var.sap_ers_instance_id) == 2
    error_message = "ERS Instance ID must have 2 chars."
  }
}

variable "sap_ers_root_user" {
  description = "Set ERS root user."
  type        = string
  default     = "root"
}

variable "sap_ers_root_password" {
  description = "Set ERS password for root user."
  type        = string
  default     = ""
}

variable "sap_ers_vip_address" {
  description = "Set ERS VIP address."
  type        = string
  default     = "10.0.0.2"
}

variable "sap_ers_vip_hostname" {
  description = "Set ERS VIP hostname."
  type        = string
  default     = "ers-vip"

  validation {
    condition     = length(var.sap_ers_vip_hostname) <= 13
    error_message = "VIP hostname must not exceed 13 chars."
  }
}

# MISC
variable "sid_adm_password" {
  description = "Password for sidadmn"
  type        = string
  default     = ""
}

variable "sap_adm_password" {
  description = "Password for sidadm user"
  type        = string
  default     = ""
}

variable "master_password" {
  description = "Password for sapadm user"
  type        = string
  default     = ""
}

variable "sapmnt_path" {
  description = "SAP profile path after installation"
  type        = string
  default     = "/sapmnt"
}

variable "sidadm_user_uid" {
  description = "UID for SAP instance (ASCS/ERS)"
  type        = string
  default     = "1000"
}

variable "sidadm_user_gid" {
  description = "GUID for SAP instance (ASCS/ERS)"
  type        = string
  default     = "1000"
}

variable "sapmnt_inst_media" {
  description = "Path for NW media folder"
  type        = string
  default     = ""
}

variable "swpm_folder" {
  description = "Path for SWPM installation"
  type        = string
  default     = ""
}

variable "sapexe_folder" {
  description = "Path for SAP kernel installation"
  type        = string
  default     = ""
}

variable "additional_dvds" {
  description = "Path for additional DVDs"
  type        = any
}


###########
# SAP HANA
###########
variable "sap_hana_host" {
  description = "SAP HANA host"
  type        = string
}

variable "sap_hana_ip" {
  description = "SAP HANA host"
  type        = string
}

variable "sap_hana_sid" {
  description = "SAP HANA sid"
  type        = string

}

variable "sap_hana_instance" {
  description = "SAP HANA instance"
  type        = string
  default     = "00"

  validation {
    condition     = length(var.sap_hana_instance) == 2
    error_message = "HANA Instance SID must have 2 chars."
  }
}

variable "sap_hana_password" {
  description = "SAP HANA password"
  type        = string
}


#######
# Tags
#######
variable "tags" {
  description = "Tags for resources."
  type        = map(any)
  default     = {}
}
