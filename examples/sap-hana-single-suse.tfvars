##################
# Cloud resources
##################
rg_exists       = false
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


######
# VMs
######
vms = [
  {
    name  = "hana"
    size  = "Standard_D16s_v5"
    image = {
      publisher = "SUSE"
      offer     = "sles-sap-15-sp4-byos"
      sku       = "gen2"
      version   = "latest"
    }
    add_pub_ip         = true
    pub_ip_persist     = true
    priv_ip_dynamic    = false
    priv_ip_addr       = "10.50.4.10"
    add_boot_diag      = true
    disk_type          = "Premium_LRS"
    disk_size_gb       = 200
    add_extra_disk     = true
    extra_disk_size_gb = 1024
    net_accel          = true
    cloudinit          = "files/cloud-init-sap-hana.yaml"
    swap_size          = 8192
    os_registration    = true
    reg_code           = "SUSE_REG_CODE"
    reg_email          = "email@company.com"
    product_id         = "NW750.HDB.ABAPHA"
    saptune_solution   = "HANA"
    sap_instance       = "hana"
  },
]


#######
# MISC
#######
sid_adm_password  = "Passw0rd123"
sap_adm_password  = "Passw0rd123"
master_password   = "Passw0rd123"
sapmnt_path       = "/sapmnt"
sidadm_user_uid   = "1001"
sidadm_user_gid   = "1001"
sapmnt_inst_media = "/mnt/sapmedia/hana"
swpm_folder       = "/mnt/sapmedia/swpm_"
sapexe_folder     = "/mnt/sapmedia/kernel_novo/part1"
additional_dvds   = "/mnt/sapmedia/misc"


#######
# HANA
#######
sap_hana_host     = "hana"
sap_hana_ip       = "9.9.9.9"
sap_hana_sid      = "HDB"
sap_hana_instance = "00"
sap_hana_password = "Password123"


#################
# SAP Monitoring
#################
enable_monitoring = true
