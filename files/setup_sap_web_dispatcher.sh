#!/bin/bash

# Redirect bash output
LOG_FILE="/root/cloud-init-setup.log"
exec > $LOG_FILE 2>&1

# Start time
echo "Start time: $(date)"

# Load terraform vars
echo "Loading terraform variables ..."
while [ ! -f /run/scripts/vars ]; do sleep 1; done
source /run/scripts/vars

# Setup swap using Azure device block
# echo "Enabling swap using Azure Linux Agent ..."
# sed -i "s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/" /etc/waagent.conf
# sed -i "s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=${vm_swap_size}/" /etc/waagent.conf
# systemctl restart waagent.service
# Due to error in the Azure Agent we create swap file manually
if [ ! -f '/mnt/swapfile' ]; then
  fallocate --length ${vm_swap_size}MiB /mnt/swapfile
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile
  swapon /mnt/swapfile
fi

# SUSE Version
OS_VER_MAJOR=$(sed -n 's/^VERSION="\(.*\)-.*/\1/p' /etc/os-release)
OS_VER_FULL=$(sed -n 's/^VERSION_ID="\(.*\)"/\1/p' /etc/os-release)

# Register system
if [ ${vm_os_registration} = true ]; then
  SUSEConnect --cleanup
  SUSEConnect -r ${vm_reg_code} -e ${vm_reg_email}
fi

# Refresh repos
zypper ref

# Enable SUSE modules
if [ ${OS_VER_MAJOR} == "12" ]; then
  SUSEConnect -p sle-module-public-cloud/12/x86_64
else
  SUSEConnect -p sle-module-public-cloud/${OS_VER_FULL}/x86_64
fi

# Update system
echo "Updating packages ..."
zypper -n up -l

# Install SUSE packages for SAP Application
zypper -n in -t pattern sap_server sap-nw ha_sles
zypper -n in habootstrap-formula sapnwbootstrap-formula \
  salt-minion socat resource-agents fence-agents \
  sap-suse-cluster-connector python3-prometheus_client patch \
  cloud-netconfig-azure

if [ ${OS_VER_MAJOR} == "12" ]; then
  zypper -n in python-azure-identity python-azure-mgmt-compute
else
  zypper -n in python3-azure-identity python3-azure-mgmt-compute
fi

# Load list variables
vm_names=(${vm_names})
vm_ips=(${vm_ips})
additional_dvds=(${additional_dvds})

# Adding host information to /etc/hosts
len=${#vm_names[@]}
for (( i=0; i<$len; i++ )); do
  echo "${vm_ips[$i]}    ${vm_names[$i]}" >> /etc/hosts
done


# Mount HANA Media
if [ ${sap_media_stg_enabled} = true ]; then
  echo "Mouting SAP HANA Media ..."
  if [ "${sap_media_pe_private_ip}" == "" ]; then
    azure_share="${sap_media_stg_account}.file.core.windows.net"
  else
    azure_share="${sap_media_pe_private_ip}"
  fi
  if [ ${sap_media_stg_type} == "smb" ]; then
    [ ! -d ${sap_media_local_mount} ] && mkdir -p ${sap_media_local_mount}
    [ ! -d "/etc/smbcredentials" ] && mkdir -p /etc/smbcredentials
    smbcredfile="/etc/smbcredentials/${sap_media_stg_account}.cred"
    if [ ! -f ${smbcredfile} ]; then
      cat <<EOF > ${smbcredfile}
username=${sap_media_stg_account}
password=${sap_media_stg_access_key}
EOF
      chmod 600 ${smbcredfile}
      smb_options="vers=3.0,credentials=${smbcredfile},dir_mode=0777,file_mode=0777,serverino"
      if [ ${sap_media_local_add_fstab} = true ]; then
        echo "//${azure_share}/${sap_media_stg_remote_path}  ${sap_media_local_mount}  cifs  ${smb_options}" >> /etc/fstab
        mount ${sap_media_local_mount}
      else
        mount -t cifs //${azure_share}/${sap_media_stg_remote_path} \
          ${sap_media_local_mount} -o ${smb_options}
      fi
    fi
  else
    if [ ${sap_media_stg_type} == "nfsv3" ]; then
      nfs_options="vers=3"
    else
      nfs_options="vers=4,minorversion=1,sec=sys"
    fi
    [ ! -d ${sap_media_local_mount} ] && mkdir -p ${sap_media_local_mount}
    mount -t nfs ${azure_share}:/${sap_media_stg_account}/${sap_media_stg_remote_path} ${sap_media_local_mount} -o ${nfs_options}
    if [ ${sap_media_local_add_fstab} = true ]; then
      echo "${azure_share}:${sap_media_stg_account}/${sap_media_stg_remote_path}  ${sap_media_local_mount}  nfs  ${nfs_options}" >> /etc/fstab
      mount ${sap_media_local_mount}
    else
      mount -t nfs ${azure_share}:${sap_media_stg_account}/${sap_media_stg_remote_path} \
        ${sap_media_local_mount} -o ${nfs_options}
    fi
  fi
fi

# Remove authorized_keys file
[ -f /root/.ssh/authorized_keys ] && rm -r /root/.ssh/authorized_keys 

# Set root password
echo "Changing root password ..."
pwd=$(salt-call --local shadow.gen_password "${admin_password}" --out txt | awk '{print $2}')
salt-call --local shadow.set_password root \'${pwd}\'

# Create unattended file for SAP Webdispatcher
# References:
# https://launchpad.support.sap.com/#/notes/2230669
# https://blogs.sap.com/2022/04/02/sap-on-azure-sap-web-dispatcher-highly-availability-setup-and-virtual-hostname-ip-configuration-with-azure-load-balancer/
# https://blogs.sap.com/2021/06/08/sap-web-dispatcher-installation-step-by-step/
# https://blogs.sap.com/2016/10/20/easier-unattended-execution-software-provisioning-manager/
# https://help.sap.com/doc/saphelp_nw73/7.3.16/en-US/48/997375ec0973e9e10000000a42189b/frameset.htm
echo "Creating unattended file for webdispatcher installation ..."
WEBDISP_UNATTENDED_FILE="/tmp/inifile.params"
cat <<EOF > ${WEBDISP_UNATTENDED_FILE}
##########################################################################################################################################
#                                                                                                                                        #
# Installation service 'Generic Options > SAP Web Dispatcher > SAP Web Dispatcher (Unicode)', product id '${vm_product_id}' #
#                                                                                                                                        #
##########################################################################################################################################

# Password for the Diagnostics Agent specific <dasid>adm user. Provided value may be encoded.
# DiagnosticsAgent.dasidAdmPassword = 

# Windows domain in which the Diagnostics Agent users must be created. This is an optional property (Windows only).
# DiagnosticsAgent.domain = 

# Windows only: Password for the Diagnostics Agent specific 'SAPService<DASID>' user.
# DiagnosticsAgent.sapServiceDASIDPassword = 

# Specify whether the all operating system users are to be removed from group 'sapinst' after the execution of Software Provisioning Manager has completed.
# NW_Delete_Sapinst_Users.removeUsers = false

# Master password
NW_GetMasterPassword.masterPwd = ${master_password}

# Human readable form of the default login language to be preselected in SAPGUI. This Parameter is potentialy prompted in addition in the screen that also asks for the <SAPSID>. It is only prompted in systems that have an ABAP stack. It is prompted for installation but not for system copy. It is asked in those installations, that perform the ABAP load. That could be the database load installation in case of a distributed system szenario, or in case of a standard system installation with all instances on one host. This Parameter is saved in the 'DEFAULT' profile. It is has no influence on language settings in a Java stack. Valid names are stored in a table of subcomponent 'NW_languagesInLoadChecks'. The available languages must be declaired in the 'LANGUAGES_IN_LOAD' parameter of the 'product.xml' file . In this file, the one-character representation of the languages is used. Check the same table in subcomponent 'NW_languagesInLoadChecks'.
# NW_GetSidNoProfiles.SAP_GUI_DEFAULT_LANGUAGE = 

# Windows only: The drive to use
# NW_GetSidNoProfiles.sapdrive = 

# Unix only: The SAP mount directory path. Default value is '/sapmnt'.
# NW_GetSidNoProfiles.sapmnt = ${sapmnt_path}

# The SAP system ID <SAPSID> of the system to be installed
NW_GetSidNoProfiles.sid = ${sap_ascs_instance_sid}

# Only use this parameter if recommended by SAP.
# NW_GetSidNoProfiles.strictSidCheck = true

# Specify whether this system is to be a Unicode system.
# NW_GetSidNoProfiles.unicode = true

# DEPRECATED, DO NOT USE!
# NW_SAPCrypto.SAPCryptoFile = ${sap_media_local_mount}

# SAP INTERNAL USE ONLY
# NW_System.installSAPHostAgent = true

# DEPRECATED, DO NOT USE!
# NW_Unpack.dbaToolsSar = 

# DEPRECATED, DO NOT USE!
# NW_Unpack.igsExeSar = 

# DEPRECATED, DO NOT USE!
# NW_Unpack.igsHelperSar = 

# DEPRECATED, DO NOT USE!
# NW_Unpack.sapExeDbSar = 

# DEPRECATED, DO NOT USE!
# NW_Unpack.sapExeSar = 

# DEPRECATED, DO NOT USE!
# NW_Unpack.sapJvmSar = 

# DEPRECATED, DO NOT USE!
# NW_Unpack.xs2Sar = 

# If  this parameter is set to 'true' the message server is configured, that is parameters 'msHost', 'backEndSID', and 'msHTTPPost' are mandatory.
# NW_Webdispatcher_Instance.configureSystemConnectivity = true

# SAP Web Dispatcher instance number. Leave empty for default.
NW_Webdispatcher_Instance.wdInstanceNumber = 00

# SAP offers the option to skip setting of security profile parameters (NOT recommended) only for compatibility reasons. Set to true and the file with recommended security settings will not be taken into consideration. See SAP Note 2714839 for security recommendations.
# NW_adaptProfile.skipSecurityProfileSettings = false

# SAP INTERNAL USE ONLY
# NW_adaptProfile.templateFiles = 

# The FQDN of the system
# NW_getFQDN.FQDN = 

# SAP INTERNAL USE ONLY
# NW_getFQDN.resolve = true

# Specify whether you want to set FQDN for the system.
# NW_getFQDN.setFQDN = true

# Activate Internet Connection Framework (ICF) nodes
NW_webdispatcher_Instance.activateICF = false

# Back-end SAP system ID. Mandatory if 'NW_Webdispatcher_Instance.configureSystemConnectivity' is set to 'true'.
NW_webdispatcher_Instance.backEndSID = ${sap_ascs_instance_sid}

# There are three types of encryption modes: 'Always' (default), 'depending on the incoming protocol', 'Never'
# NW_webdispatcher_Instance.encryptionMode = Always

# Back-end message server HTTP port. Mandatory if 'NW_Webdispatcher_Instance.configureSystemConnectivity' is set to 'true'
NW_webdispatcher_Instance.msHTTPPort = 8101

# Back-end message server host. Mandatory if 'NW_Webdispatcher_Instance.configureSystemConnectivity' is set to 'true'.
NW_webdispatcher_Instance.msHost = ${sap_ascs_vip_address}

# SAP System Client. Mandatory if 'NW_Webdispatcher_Instance.activateICF' is set to 'true'
# NW_webdispatcher_Instance.rfcClient = 000

# Application Server Instance Host. Mandatory if 'NW_Webdispatcher_Instance.activateICF' is set to 'true'
NW_webdispatcher_Instance.rfcHost = ${sap_ascs_vip_address}

# Application Server Instance Number. Mandatory if 'NW_Webdispatcher_Instance.activateICF' is set to 'true'
# NW_webdispatcher_Instance.rfcInstance = 

# Password of RFC User. Mandatory if 'NW_Webdispatcher_Instance.activateICF' is set to 'true'
# NW_webdispatcher_Instance.rfcPassword = 

# RFC User. Mandatory if 'NW_Webdispatcher_Instance.activateICF' is set to 'true'
# NW_webdispatcher_Instance.rfcUser = DDIC

# Operating systems have restrictions for maximum number of open 'file handles' (sockets) for each process. Default is 2048. Provide a much higher value for  scenarios with heavy workload.
NW_webdispatcher_Instance.scenarioSize = 500

# Set this parameter to 'true' if the SAP Web Dispatcher HTTP Port is to be used.
# NW_webdispatcher_Instance.useWdHTTPPort = false

# HTTP Port of SAP Web Dispatcher. You can only specify this parameter if 'NW_webdispatcher_Instance.useWdHTTPPort' is set to 'true'.
NW_webdispatcher_Instance.wdHTTPPort = 8000

# HTTPS Port of SAP Web Dispatcher.
NW_webdispatcher_Instance.wdHTTPSPort = 44300

# Virtual host name for the SAP Web Dispatcher instance. Leave empty if you want to use the default physical host name. The virtual host name must already be bound to a local network interface.
NW_webdispatcher_Instance.wdVirtualHostname = ${vm_name}

# The ASP device name where the SAP system will be in installed. The property is IBM i only.
# Values from 1 to 256 can be specified. The default is 1, the System ASP.
# OS4.DestinationASP = 

# The folder containing all archives that have been downloaded from http://support.sap.com/swdc and are supposed to be used in this procedure
archives.downloadBasket = ${sap_media_local_mount}

# Windows only: The domain of the SAP Host Agent user
# hostAgent.domain = 

# Password for the 'sapadm' user of the SAP Host Agent
hostAgent.sapAdmPassword = ${sap_adm_password}

# Windows only: The domain of all users of this SAP system. Leave empty for default.
# nwUsers.sapDomain = 

# Windows only: The password of the 'SAPServiceSID' user
# nwUsers.sapServiceSIDPassword = 

# UNIX only: The user ID of the 'sapadm' user, leave empty for default. The ID is ignored if the user already exists.
# nwUsers.sapadmUID = 

# UNIX only: The group id of the 'sapsys' group, leave empty for default. The ID is ignored if the group already exists.
# nwUsers.sapsysGID = 

# UNIX only: The user id of the <sapsid>adm user, leave empty for default. The ID is ignored if the user already exists.
# nwUsers.sidAdmUID = 

# The password of the '<sapsid>adm' user
nwUsers.sidadmPassword = ${sid_adm_password}
EOF

# Unattended installation of SAP Web Dispatcher
# For testing connect to the URL https://IP:44300/sap/wdisp/admin/public/default.html with user webadm
echo "Installing SAP Web Dispatcher ..."
${swpm_folder}/sapinst \
  SAPINST_INPUT_PARAMETERS_URL="${WEBDISP_UNATTENDED_FILE}" \
  SAPINST_EXECUTE_PRODUCT_ID="${vm_product_id}" \
  SAPINST_SKIP_DIALOGS=true \
  SAPINST_START_GUISERVER=false

# End time
echo "End time: $(date)"
