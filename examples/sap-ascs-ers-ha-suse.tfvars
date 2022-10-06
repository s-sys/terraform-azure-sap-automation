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
vnet_exists   = false
vnet_name     = "vnet"
vnet_addr     = "10.50.0.0/16"
vnet_rg       = "RG_SAP"


#################
# Network Subnet
#################
subnet_exists = false
subnet_name   = "sNET"
subnet_addr   = "10.50.4.0/24"


############
# NSG rules
############
nsg_enabled = true
nsg_exists  = false
nsg_name    = "nsg"
nsg_rg      = "RG_SAP"
nsg_rules   = [
  { 
    name                       = "All"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    enabled                    = true
  },
]


###################
# Availability set
###################
availability_set_enabled = true
availability_set_name    = "as_sap"


############################
# Proximity Placement Group
############################
proximity_pg_enabled = true
proximity_pg_exists  = false
proximity_pg_name    = "ppg_sap"
proximity_pg_rg      = "RG_SAP"


################################
# Storage account for SAP Media
################################
sap_media_stg_enabled      = true
sap_media_stg_type         = "smb"
sap_media_stg_exists       = true
sap_media_stg_account      = "MY_STGA"
sap_media_stg_rg           = "RG-STGA"
sap_media_stg_access_key   = "MY_ACCESS_KEY"
sap_media_stg_remote_path  = "/hanamedia"
sap_media_local_mount      = "/mnt/sapmedia"
sap_media_local_add_fstab  = false
sap_media_stg_pe_enabled   = true
sap_media_stg_pe_exists    = false
sap_media_stg_pe_name      = ""
# For new resource fields below must be filled
sap_media_stg_tier         = "Standard"
sap_media_stg_repl         = "LRS"
sap_media_stg_account_kind = "StorageV2"


###########################################
# Storage account for SAP Application data
###########################################
data_stg_enabled         = true
data_stg_exists          = true
data_stg_account         = "MY_STGA"
data_stg_rg              = "RG-STGA"
data_stg_remote_path     = "/sapecp"
data_stg_remote_clean    = true
data_stg_local_add_fstab = true
data_stg_pe_enabled      = true
data_stg_pe_exists       = false
data_stg_pe_name         = ""
# For new resource fields below must be filled
data_stg_tier            = "Premium"
data_stg_repl            = "LRS"
data_stg_account_kind    = "FileStorage"


########################################
# Storage account for SAP saptrans data
########################################
saptrans_stg_type            = "stga"
saptrans_stg_enabled         = true
saptrans_stg_exists          = true
saptrans_stg_account         = "MY_STGA"
saptrans_stg_rg              = "RG-STGA"
saptrans_stg_remote_path     = "/saptrans"
saptrans_stg_remote_clean    = true
saptrans_stg_local_add_fstab = true
saptrans_stg_pe_enabled      = true
saptrans_stg_pe_exists       = false
saptrans_stg_pe_name         = ""
# For new resource fields below must be filled
saptrans_stg_tier            = "Premium"
saptrans_stg_repl            = "LRS"
saptrans_stg_account_kind    = "FileStorage"


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
# Azure Fencing Application
############################
fencing_enabled    = true
fencing_app_exists = false
fencing_app_name   = "sap_fencing_app"
fencing_perms_rg   = false
fencing_app_secret = ""


############################
# Load balancer for cluster
############################
lb_create           = true
lb_create_public_ip = false
lb_name             = "lb_sap"
lb_sku              = "Standard"
# Load Balancing rules and probes
lb_frontend_ip      = [
  {
    name       = "ascs"
    private_ip = "10.50.4.200"
  },
  {
    name       = "ers"
    private_ip = "10.50.4.201"
  },
]
lb_probe_rules = [
  {
    name             = "ascs"
    port             = 62001
    protocol         = "Tcp"
    interval         = 5
    number_of_probes = 2
  },
  {
    name             = "ers"
    port             = 62110
    protocol         = "Tcp"
    interval         = 5
    number_of_probes = 2
  },
]
lb_rules = [
  {
    name                    = "port_3201"
    frontend_name           = "ascs"
    probe_name              = "ascs"
    protocol                = "Tcp"
    frontend_port           = 3201
    backend_port            = 3201
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_3601"
    frontend_name           = "ascs"
    probe_name              = "ascs"
    protocol                = "Tcp"
    frontend_port           = 3601
    backend_port            = 3601
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_3901"
    frontend_name           = "ascs"
    probe_name              = "ascs"
    protocol                = "Tcp"
    frontend_port           = 3901
    backend_port            = 3901
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_8101"
    frontend_name           = "ascs"
    probe_name              = "ascs"
    protocol                = "Tcp"
    frontend_port           = 8101
    backend_port            = 8101
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_50113"
    frontend_name           = "ascs"
    probe_name              = "ascs"
    protocol                = "Tcp"
    frontend_port           = 50113
    backend_port            = 50113
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_50114"
    frontend_name           = "ascs"
    probe_name              = "ascs"
    protocol                = "Tcp"
    frontend_port           = 50114
    backend_port            = 50114
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_50116"
    frontend_name           = "ascs"
    probe_name              = "ascs"
    protocol                = "Tcp"
    frontend_port           = 50116
    backend_port            = 50116
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_3210"
    frontend_name           = "ers"
    probe_name              = "ers"
    protocol                = "Tcp"
    frontend_port           = 3210
    backend_port            = 3210
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_3310"
    frontend_name           = "ers"
    probe_name              = "ers"
    protocol                = "Tcp"
    frontend_port           = 3310
    backend_port            = 3310
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_51013"
    frontend_name           = "ers"
    probe_name              = "ers"
    protocol                = "Tcp"
    frontend_port           = 51013
    backend_port            = 51013
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_51014"
    frontend_name           = "ers"
    probe_name              = "ers"
    protocol                = "Tcp"
    frontend_port           = 51014
    backend_port            = 51014
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
  {
    name                    = "port_51016"
    frontend_name           = "ers"
    probe_name              = "ers"
    protocol                = "Tcp"
    frontend_port           = 51016
    backend_port            = 51016
    enable_floating_ip      = false
    idle_timeout_in_minutes = 4
    load_distribution       = "SourceIPProtocol"
    enable_tcp_reset        = false
    disable_outbound_snat   = true
  },
]


######
# VMs
######
vms = [
  {
    name  = "sap-ecp-1"
    size  = "Standard_D4s_v5"
    image = {
      publisher = "SUSE"
      offer     = "sles-sap-15-sp3-byos"
      sku       = "gen2"
      version   = "latest"
    }
    add_pub_ip         = true
    pub_ip_persist     = true
    priv_ip_dynamic    = false
    priv_ip_addr       = "10.50.4.202"
    add_boot_diag      = true
    disk_type          = "Standard_LRS"
    disk_size_gb       = 20
    add_extra_disk     = false
    extra_disk_size_gb = 0
    net_accel          = true
    cloudinit          = "files/cloud-init-sap-netweaver-ha.yaml"
    swap_size          = 2048
    os_registration    = true
    reg_code           = "MY_SUSE_REG_CODE"
    reg_email          = "email@company.com"
    product_id         = "NW750.HDB.ABAPHA"
    saptune_solution   = "NETWEAVER"
    sap_instance       = "ascs"
  },
  {
    name  = "sap-ecp-2"
    size  = "Standard_D4s_v5"
    image = {
      publisher = "SUSE"
      offer     = "sles-sap-15-sp3-byos"
      sku       = "gen2"
      version   = "latest"
    }
    add_pub_ip         = true
    pub_ip_persist     = true
    priv_ip_dynamic    = false
    priv_ip_addr       = "10.50.4.203"
    add_boot_diag      = true
    disk_type          = "Standard_LRS"
    disk_size_gb       = 20
    add_extra_disk     = false
    extra_disk_size_gb = 0
    net_accel          = true
    cloudinit          = "files/cloud-init-sap-netweaver-ha.yaml"
    swap_size          = 2048
    os_registration    = true
    reg_code           = "MY_SUSE_REG_CODE"
    reg_email          = "email@company.com"
    product_id         = "NW750.HDB.ABAPHA"
    saptune_solution   = "NETWEAVER"
    sap_instance       = "ers"
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
swpm_folder       = "/mnt/sapmedia/swpm_"
sapexe_folder     = "/mnt/sapmedia/kernel_novo/part1"
additional_dvds   = "/mnt/sapmedia/misc"


#######
# HANA
#######
sap_hana_host     = "hana"
sap_hana_ip       = "9.9.9.9"
sap_hana_sid      = "ECP"
sap_hana_instance = "00"
sap_hana_password = "Password123"


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
