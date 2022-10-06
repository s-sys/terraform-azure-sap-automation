#!/bin/bash

# Redirect bash output
LOG_FILE="/root/cloud-init-setup.log"
exec > $LOG_FILE 2>&1

# Start time
echo "Start time: $(date)"

# Load terraform vars
while [ ! -f /run/scripts/vars ]; do sleep 1; done
source /run/scripts/vars

# Setup swap using Azure device block
sed -i "s/ResourceDisk.Format=n/ResourceDisk.Format=y/" /etc/waagent.conf
sed -i "s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/" /etc/waagent.conf
sed -i "s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=${vm_swap_size}/" /etc/waagent.conf
sed -i "s/AutoUpdate.Enabled=n/AutoUpdate.Enabled=y/" /etc/waagent.conf
sed -i "s/ResourceDisk.MountPoint=.*/ResourceDisk.MountPoint=\/mnt\/swapfile/" /etc/waagent.conf
systemctl restart waagent.service
 
# Wait for disks
disks=(b)
i=0
echo -n "Waiting for disk /dev/sd${disks[i]}... "
while [ ! -b /dev/sd${disks[i]} ]; do sleep 1; done
echo "[ OK ]"
rescan-scsi-bus.sh

# Format and mount disks
[ -b /dev/sd${disks[i]}1 ] && continue
echo "Partitioning disk /dev/sd${disks[i]}..."
parted --script /dev/sd${disks[i]} mklabel gpt mkpart primary xfs 0% 100%
partprobe /dev/sd${disks[i]}
echo "Formating disk /dev/sd${disks[i]}1 as XFS..."
mkfs.xfs /dev/sd${disks[i]}1
[ ! -d /hana ] && mkdir -p /hana
echo "Mounting partition/dev/sd${disks[i]}1 at /hana..."
mount /dev/sd${disks[i]}1 /hana
[ ! -d /hana/data ]   && mkdir -p /hana/data
[ ! -d /hana/log ]    && mkdir -p /hana/log
[ ! -d /hana/shared ] && mkdir -p /hana/shared
uuid=$(lsblk -n -f /dev/sd${disks[i]}1 -o UUID)
echo "Adding mouting entry /hana to /etc/fstab..."
echo "UUID=\"${uuid}\"  /hana  xfs  defaults,noatime  0  0" >> /etc/fstab

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
zypper -n up -l

# Install SUSE packages for HANA
zypper -n in -t pattern sap-hana
zypper -n in saphanabootstrap-formula
zypper -n in salt-minion


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


# Configure salt for HANA deployment
cat <<EOF >/etc/salt/minion.d/hana.conf
file_roots:
  base:
    - /srv/salt
    - /usr/share/salt-formulas/states
EOF

[ ! -d /srv/pillar ] && mkdir -p /srv/pillar
cat <<EOF >/srv/pillar/top.sls
base:
  '*':
    - hana
EOF

exporter=""
if [ ${enable_monitoring} = true ]; then
exporter="""      exporter:
        exposition_port: 9668
        multi_tenant: true
        user: \"SYSTEM\"
        password: \"${sap_hana_password}\"
        port: 3${sap_hana_instance}13
        timeout: 600
"""
fi 

cat <<EOF > /srv/pillar/hana.sls
hana:
  install_packages: true
  saptune_solution: "HANA"
  software_path: "${sapmnt_inst_media}"
  ha_enabled: false
  monitoring_enabled: ${enable_monitoring}

  nodes:
    - host: "${vm_name}"
      sid: "${sap_hana_sid}"
      instance: "${sap_hana_instance}"
      password: "${sap_hana_password}"
      install:
        root_user: "root"
        root_password: "${admin_password}"
        system_user_password: "${master_password}"
        sapadm_password: "${sap_adm_password}"
${exporter}
EOF

# Run salt for SAP HANA deployment
salt-call --local saltutil.sync_all
salt-call --local -l profile state.apply hana

# End time
echo "End time: $(date)"
