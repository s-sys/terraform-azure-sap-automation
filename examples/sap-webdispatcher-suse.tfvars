##################
# Cloud resources
##################
rg_exists       = true
resource_group  = "RG_SAP"
location        = "eastus"
admin_username  = "cloudadmin"
admin_password  = "MY_PASSWORD"


###############
# Network Vnet
###############
vnet_exists   = true
vnet_name     = "vnet"
vnet_addr     = "10.50.0.0/16"
vnet_rg       = "RG_SAP"


#################
# Network Subnet
#################
subnet_exists = true
subnet_name   = "sNET"
subnet_addr   = "10.50.4.0/24"


############
# NSG rules
############
nsg_enabled = true
nsg_exists  = true
nsg_name    = "nsg"
nsg_rg      = "RG_SAP"
nsg_rules   = []


###################
# Availability set
###################
availability_set_enabled = true
availability_set_name    = "as_webdispatcher"


############################
# Proximity Placement Group
############################
proximity_pg_enabled = true
proximity_pg_exists  = false
proximity_pg_name    = "ppg_webdispatcher"
proximity_pg_rg      = "RG_SAP"


################################
# Storage account for SAP Media
################################
sap_media_stg_enabled      = true
sap_media_stg_type         = "smb"
sap_media_stg_exists       = true
sap_media_stg_account      = "stga1"
sap_media_stg_rg           = "RG-STGA"
sap_media_stg_access_key   = "MY_ACCESS_KEY"
sap_media_stg_remote_path  = "/hanamedia"
sap_media_local_mount      = "/mnt/sapmedia"
sap_media_local_add_fstab  = false
sap_media_stg_pe_enabled   = true
sap_media_stg_pe_exists    = true
sap_media_stg_pe_name      = ""
# For new resource fields below must be filled
sap_media_stg_tier         = "Standard"
sap_media_stg_repl         = "LRS"
sap_media_stg_account_kind = "StorageV2"


###########################################
# Storage account for SAP Application data
###########################################
data_stg_enabled         = false
data_stg_exists          = true
data_stg_account         = "MY_STGA"
data_stg_rg              = "RG-STGA"
data_stg_remote_path     = "/sapecp"
data_stg_remote_clean    = true
data_stg_local_add_fstab = true
data_stg_pe_enabled      = false
data_stg_pe_exists       = false
data_stg_pe_name         = ""
# For new resource fields below must be filled
data_stg_tier            = "Premium"
data_stg_repl            = "LRS"
data_stg_account_kind    = "FileStorage"


################################
# Storage account for instances
################################
vm_data_stg_exists       = true
vm_data_stg_account      = "MY_STGA"
vm_data_stg_rg           = "RG-STGA"
# For new resource fields below must be filled
vm_data_stg_tier         = "Premium"
vm_data_stg_repl         = "LRS"
vm_data_stg_account_kind = "BlockBlobStorage"


#######################################
# Storage account for Boot Diagnostics
#######################################
boot_diag_stg_enabled      = true
boot_diag_stg_exists       = true
boot_diag_stg_account      = "MY_STGA"
boot_diag_stg_rg           = "RG-STGA"
# For new resource fields below must be filled
boot_diag_stg_tier         = "Standard"
boot_diag_stg_repl         = "LRS"
boot_diag_stg_account_kind = "StorageV2"


############################
# Load balancer for cluster
############################
lb_create           = true
lb_create_public_ip = false
lb_name             = "lb_webdispatcher"
lb_sku              = "Standard"
# Load Balancing rules and probes
lb_frontend_ip      = [
  {
    name       = "webdispatcher"
    private_ip = "10.50.4.210"
  },
]
lb_probe_rules = [
  {
    name             = "probe_webdispatcher"
    port             = 8020
    protocol         = "Https"
    request_path     = "/sap/public/icman/ping"
    interval         = 5
    number_of_probes = 2
  },
]
lb_rules = [
  {
    name                    = "port_44300"
    frontend_name           = "webdispatcher"
    probe_name              = "probe_webdispatcher"
    protocol                = "Tcp"
    frontend_port           = 44300
    backend_port            = 44300
    enable_floating_ip      = false
    idle_timeout_in_minutes = 30
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = true
    disable_outbound_snat   = true
  },
  {
    name                    = "port_8020"
    frontend_name           = "webdispatcher"
    probe_name              = "probe_webdispatcher"
    protocol                = "Tcp"
    frontend_port           = 8020
    backend_port            = 8020
    enable_floating_ip      = false
    idle_timeout_in_minutes = 30
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = true
    disable_outbound_snat   = true
  },
]


######
# VMs
######
vms = [
  {
    name  = "sap-web-1"
    size  = "Standard_D2as_v5"
    image = {
      publisher = "SUSE"
      offer     = "sles-sap-15-sp4-byos"
      sku       = "gen2"
      version   = "latest"
    }
    add_pub_ip         = true
    pub_ip_persist     = true
    priv_ip_dynamic    = false
    priv_ip_addr       = "10.50.4.211"
    add_boot_diag      = true
    disk_type          = "Standard_LRS"
    disk_size_gb       = 20
    add_extra_disk     = false
    extra_disk_size_gb = 0
    net_accel          = true
    cloudinit          = "files/cloud-init-sap-web-dispatcher.yaml"
    swap_size          = 2048
    os_registration    = true
    reg_code           = "SUSE_REG_CODE"
    reg_email          = "email@company.com"
    product_id         = "NW_Webdispatcher:NW750.IND.PD"
    saptune_solution   = "S4HANA-APPSERVER"
    sap_instance       = "webdispatcher"
  },
  {
    name  = "sap-web-2"
    size  = "Standard_D2as_v5"
    image = {
      publisher = "SUSE"
      offer     = "sles-sap-15-sp4-byos"
      sku       = "gen2"
      version   = "latest"
    }
    add_pub_ip         = true
    pub_ip_persist     = true
    priv_ip_dynamic    = false
    priv_ip_addr       = "10.50.4.212"
    add_boot_diag      = true
    disk_type          = "Standard_LRS"
    disk_size_gb       = 20
    add_extra_disk     = false
    extra_disk_size_gb = 0
    net_accel          = true
    cloudinit          = "files/cloud-init-sap-web-dispatcher.yaml"
    swap_size          = 2048
    os_registration    = true
    reg_code           = "SUSE_REG_CODE"
    reg_email          = "email@company.com"
    product_id         = "NW_Webdispatcher:NW750.IND.PD"
    saptune_solution   = "S4HANA-APPSERVER"
    sap_instance       = "webdispatcher"
  },
]


################
# SAP variables
################
# ASCS
sap_ascs_instance_sid  = "ECP"
sap_ascs_instance_id   = "01"
sap_ascs_root_user     = "root"
sap_ascs_root_password = "Passw0rd123"
sap_ascs_vip_address   = "10.50.4.200"
sap_ascs_vip_hostname  = "ecp-ascs-vip"


######
# ERS
######
sap_ers_instance_sid  = "ECP"
sap_ers_instance_id   = "10"
sap_ers_root_user     = "root"
sap_ers_root_password = "Passw0rd123"
sap_ers_vip_address   = "10.50.4.201"
sap_ers_vip_hostname  = "ecp-ers-vip"


#######
# MISC
#######
sid_adm_password  = "Passw0rd123"
sap_adm_password  = "Passw0rd123"
master_password   = "Passw0rd123"
sapmnt_path       = "/sapmnt"
sidadm_user_uid   = "1001"
sidadm_user_gid   = "1001"
sapmnt_inst_media = ""
swpm_folder       = "/mnt/sapmedia/swpm2_"
sapexe_folder     = "/mnt/sapmedia/kernel_novo/part1"
additional_dvds   = "/mnt/sapmedia/misc"


#############
# HA Cluster
#############
cluster_install  = true
cluster_unicast  = true
cluster_password = "Passw0rd"


#################
# SAP Monitoring
#################
enable_monitoring = true

#######
# Tags
#######
tags = {
  Funcao: "SAP_HA"
  Ambiente: "Producao"
  Cenario: "SAP"
  Projeto: "ECC (PAS)"
}
