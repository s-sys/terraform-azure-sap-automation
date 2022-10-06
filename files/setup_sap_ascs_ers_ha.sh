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
echo "Enabling swap using Azure Linux Agent ..."
sed -i "s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/" /etc/waagent.conf
sed -i "s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=${vm_swap_size}/" /etc/waagent.conf
systemctl restart waagent.service
 
# Create group sapsys
echo "Creating local user and groups ..."
cmd=$(getent group sapsys)
ret=$?
if [ ${ret} -ne 0 ]; then
  groupadd -g ${sidadm_user_gid} sapsys
fi
 
# Create user locally
sed -i "s/^UID_MIN\(.*\)/UID_MIN 500/g" /etc/login.defs
users=$(grep x:${sidadm_user_uid} /etc/passwd | cut -d: -f1)
baseid=1100
id_plus=0
for user in ${users}; do
  usermod -u $((baseid + id_plus)) ${user}
  id_plus=$((id_plus + 1))
done
cmd=$(getent passwd "${sap_ascs_instance_sid_lower}adm")
ret=$?
sap_ascs_instance_sid_lower=$(echo ${sap_ascs_instance_sid} | tr "[A-Z]" "[a-z]")
if [ ${ret} -ne 0 ]; then
  useradd -m -u ${sidadm_user_uid} -g ${sidadm_user_gid} "${sap_ascs_instance_sid_lower}adm"
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

# Network corrections based on https://www.suse.com/support/kb/doc/?id=000019381
echo "Changing network configuration ..."
sed -i "s/^CLOUD_NETCONFIG_MANAGE=\(.*\)/CLOUD_NETCONFIG_MANAGE=\'no\'/g" \
  /etc/sysconfig/network/ifcfg-eth0
rcnetwork reload

# Adding host information to /etc/hosts
len=${#vm_names[@]}
for (( i=0; i<$len; i++ )); do
  echo "${vm_ips[$i]}    ${vm_names[$i]}" >> /etc/hosts
done

# Give advantage time to node 1
if [ ${vm_name} == ${vm_names[1]} ]; then
  sleep 2m
fi

# Mount HANA Media
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

# Check SAP directories on NFS share
echo "Preparing SAP data area ..."
saptmp="/tmp/saptmp"
if [ "${data_stg_pe_private_ip}" == "" ]; then
  azure_share="${data_stg_account}.file.core.windows.net"
else
  azure_share="${data_stg_pe_private_ip}"
fi
nfs_options="vers=4,minorversion=1,sec=sys"
[ ! -d ${saptmp} ] && mkdir -p ${saptmp}
mount -t nfs ${azure_share}:/${data_stg_account}/${data_stg_remote_path} ${saptmp} -o ${nfs_options}
ret=$?
if [ ${ret} -eq 0 ]; then
  if [ ${data_stg_remote_clean} = true -a "${vm_name}" == "${vm_names[0]}" ]; then
    [ -d ${saptmp}/sapmnt${sap_ascs_instance_sid} ] && \
      rm -rf ${saptmp}/sapmnt${sap_ascs_instance_sid}/*
    [ -d ${saptmp}/usrsap${sap_ascs_instance_sid}ascs ] && \
      rm -rf ${saptmp}/usrsap${sap_ascs_instance_sid}ascs/*
    [ -d ${saptmp}/usrsap${sap_ascs_instance_sid}ers ] && \
      rm -rf ${saptmp}/usrsap${sap_ascs_instance_sid}ers/*
    [ -d ${saptmp}/usrsap${sap_ascs_instance_sid}sys ] && \
      rm -rf ${saptmp}/usrsap${sap_ascs_instance_sid}sys/*
  fi
  # Create directory structure only on node 1
  if [ "${vm_name}" == "${vm_names[0]}" ]; then
    [ ! -d ${saptmp}/sapmnt${sap_ascs_instance_sid} ] && \
      mkdir -p ${saptmp}/sapmnt${sap_ascs_instance_sid}
    [ ! -d ${saptmp}/usrsap${sap_ascs_instance_sid}ascs ] && \
      mkdir -p ${saptmp}/usrsap${sap_ascs_instance_sid}ascs
    [ ! -d ${saptmp}/usrsap${sap_ascs_instance_sid}ers ] && \
      mkdir -p ${saptmp}/usrsap${sap_ascs_instance_sid}ers
    [ ! -d ${saptmp}/usrsap${sap_ascs_instance_sid}sys ] && \
      mkdir -p ${saptmp}/usrsap${sap_ascs_instance_sid}sys
  fi
  umount ${saptmp}
else
  echo "Error mounting NFS directory for SAP data."
fi

# Checking SAP directory structure on filesystem
echo "Preparing local system directories for SAP ..."
[ ! -d /sapmnt/${sap_ascs_instance_sid} ] && \
  {
    mkdir -p /sapmnt/${sap_ascs_instance_sid}
    chattr +i /sapmnt/${sap_ascs_instance_sid}
  }
[ ! -d /usr/sap/trans ] && \
  {
    mkdir -p /usr/sap/trans
    chattr +i /usr/sap/trans
  }
[ ! -d /usr/sap/${sap_ascs_instance_sid}/SYS ] && \
  {
    mkdir -p /usr/sap/${sap_ascs_instance_sid}/SYS
    chattr +i /usr/sap/${sap_ascs_instance_sid}/SYS
  }
[ ! -d /usr/sap/${sap_ascs_instance_sid}/ASCS${sap_ascs_instance_id} ] && \
  {
    mkdir -p /usr/sap/${sap_ascs_instance_sid}/ASCS${sap_ascs_instance_id}
    chattr +i /usr/sap/${sap_ascs_instance_sid}/ASCS${sap_ascs_instance_id}
  }
[ ! -d /usr/sap/${sap_ascs_instance_sid}/ERS${sap_ers_instance_id} ] && \
  {
    mkdir -p /usr/sap/${sap_ascs_instance_sid}/ERS${sap_ers_instance_id}
    chattr +i /usr/sap/${sap_ascs_instance_sid}/ERS${sap_ers_instance_id}
  }

# Mount SAP data on NFS
echo "Mounting SAP data ..."
if [ "${data_stg_pe_private_ip}" == "" ]; then
  azure_share="${data_stg_account}.file.core.windows.net"
else
  azure_share="${data_stg_pe_private_ip}"
fi
nfs_options="vers=4,minorversion=1,sec=sys"
if [ ${data_stg_local_add_fstab} = true ]; then
  count=$(grep -c "${azure_share}:/${data_stg_account}" /etc/fstab)
  if [ ${count} -eq 0 ]; then
    echo "${azure_share}:/${data_stg_account}/sap${sap_ascs_instance_sid_lower}/sapmnt${sap_ascs_instance_sid}  /sapmnt/${sap_ascs_instance_sid}  nfs  ${nfs_options}" >> /etc/fstab
    echo "${azure_share}:/${data_stg_account}/sap${sap_ascs_instance_sid_lower}/usrsap${sap_ascs_instance_sid}sys  /usr/sap/${sap_ascs_instance_sid}/SYS  nfs  ${nfs_options}" >> /etc/fstab
    echo "${azure_share}:/${data_stg_account}/sap${sap_ascs_instance_sid_lower}/usrsap${sap_ascs_instance_sid}ascs  /usr/sap/${sap_ascs_instance_sid}/ASCS${sap_ascs_instance_id}  nfs  ${nfs_options}" >> /etc/fstab
    echo "${azure_share}:/${data_stg_account}/sap${sap_ascs_instance_sid_lower}/usrsap${sap_ascs_instance_sid}ers  /usr/sap/${sap_ascs_instance_sid}/ERS${sap_ers_instance_id}  nfs  ${nfs_options}" >> /etc/fstab
  fi
  mount /sapmnt/${sap_ascs_instance_sid}
  mount /usr/sap/${sap_ascs_instance_sid}/SYS
  mount /usr/sap/${sap_ascs_instance_sid}/ASCS${sap_ascs_instance_id}
  mount /usr/sap/${sap_ascs_instance_sid}/ERS${sap_ers_instance_id}
else
  mount -t nfs ${azure_share}:/${data_stg_account}/sap${sap_ascs_instance_sid_lower}/sapmnt${sap_ascs_instance_sid} \
    /sapmnt/${sap_ascs_instance_sid} -o ${nfs_options}
  mount -t nfs ${azure_share}:/${data_stg_account}/sap${sap_ascs_instance_sid_lower}/usrsap${sap_ascs_instance_sid}sys \
    /usr/sap/${sap_ascs_instance_sid}/SYS -o ${nfs_options}
  mount -t nfs ${azure_share}:/${data_stg_account}/sap${sap_ascs_instance_sid_lower}/usrsap${sap_ascs_instance_sid}ascs \
    /usr/sap/${sap_ascs_instance_sid}/ASCS${sap_ascs_instance_id} -o ${nfs_options}
  mount -t nfs ${azure_share}:/${data_stg_account}/sap${sap_ascs_instance_sid_lower}/usrsap${sap_ascs_instance_sid}ers \
    /usr/sap/${sap_ascs_instance_sid}/ERS${sap_ers_instance_id} -o ${nfs_options} 
fi

# Mount SAP saptrans data on NFS
echo "Mounting SAP trans ..."
if [ "${saptrans_stg_pe_private_ip}" == "" ]; then
  azure_share="${saptrans_stg_account}.file.core.windows.net"
else
  azure_share="${saptrans_stg_pe_private_ip}"
fi
nfs_options="vers=4,minorversion=1,sec=sys"
if [ ${saptrans_stg_local_add_fstab} = true ]; then
  count=$(grep -c "/usr/sap/trans" /etc/fstab)
  if [ ${count} -eq 0 ]; then
    if [ ${saptrans_stg_type} == "stga" ]; then
      echo "${azure_share}:/${saptrans_stg_account}/${saptrans_stg_remote_path}/${sap_ascs_instance_sid}  /usr/sap/trans  nfs  ${nfs_options}" >> /etc/fstab
    else
      echo "${saptrans_stg_remote_path}  /usr/sap/trans  nfs  vers=3" >> /etc/fstab
    fi
  fi
  mount /usr/sap/trans
else
  if [ ${saptrans_stg_type} == "stga" ]; then
    mount -t nfs ${azure_share}:/${saptrans_stg_account}/${saptrans_stg_remote_path}/${sap_ascs_instance_sid} \
      /usr/sap/trans -o ${nfs_options}
  else
    mount -t nfs ${saptrans_stg_remote_path}  /usr/sap/trans -o vers=3
  fi
fi

# Change permissions on local SAP directories
if [ ${vm_name} == ${vm_names[0]} ]; then
  chown -R ${sap_ascs_instance_sid_lower}adm:sapsys /usr/sap/${sap_ascs_instance_sid}/ASCS${sap_ascs_instance_id}
  chown -R ${sap_ascs_instance_sid_lower}adm:sapsys /usr/sap/${sap_ascs_instance_sid}/ERS${sap_ers_instance_id}
  chown -R ${sap_ascs_instance_sid_lower}adm:sapsys /usr/sap/${sap_ascs_instance_sid}/SYS
fi

# Configure salt for SAP deployment
echo "Preparing salt environment ..."
cat <<EOF >/etc/salt/minion.d/sap.conf
file_roots:
  base:
    - /srv/salt
    - /usr/share/salt-formulas/states
EOF

[ ! -d /srv/pillar ] && mkdir -p /srv/pillar
cat <<EOF >/srv/pillar/top.sls
base:
  '*':
    - cluster
    - netweaver
EOF

# Pillar for Pacemaker Cluster
cat <<EOF > /srv/pillar/cluster.sls
cluster:
  # Cluster name
  name: hacluster
  init: ${vm_names[0]}
  watchdog:
    module: softdog
    device: /dev/watchdog
  interface: eth0
  unicast: ${cluster_unicast}
  wait_for_initialization: 30
  ntp: pool.ntp.org
  monitoring_enabled: ${enable_monitoring}
  corosync:
    totem:
      token: 30000
      token_retransmits_before_loss_const: 10
      join: 60
      consensus: 36000
      max_messages: 20
      interface:
        bindnetaddr: ${vm_ip_network}
    quorum:
      expected_votes: ${vm_number}
      two_node: 1
  hacluster_password: "${cluster_password}"
  sshkeys:
    password: "${admin_password}"
  configure:
    properties:
      stonith-enabled: false
      stonith-timeout: 300
      concurrent-fencing: true
      no-quorum-policy: "ignore"
      stonith-action: "off"
    rsc_defaults:
      resource-stickiness: 1000
      migration-threshold: 5000
      failure-timeout: 600
    op_defaults:
      timeout: 600
      record-pending: true
EOF

# ADDITIONAL_DVD=$(
# for dvd in "${additional_dvds[@]}"; do
#   echo "    - ${dvd}"
# done
# )

# Pillar for Netweaver setup
cat <<EOF > /srv/pillar/netweaver.sls
netweaver:
  install_packages: true
  virtual_addresses:
    ${vm_ips[0]}: ${vm_names[0]}
    ${vm_ips[1]}: ${vm_names[1]}
    ${sap_hana_ip}: ${sap_hana_host}
    ${sap_ascs_vip_address}: ${sap_ascs_vip_hostname}
    ${sap_ers_vip_address}: ${sap_ers_vip_hostname}
  sidadm_user:
    uid: ${sidadm_user_uid}
    gid: ${sidadm_user_gid}
  sid_adm_password: ${sid_adm_password}
  sap_adm_password: ${sap_adm_password}
  master_password: ${master_password}
  clean_nfs: False
  swpm_folder: ${swpm_folder}
  sapexe_folder: ${sapexe_folder}
  installation_folder: /tmp/swpm_unattended
  additional_dvds:
    - ${additional_dvds[0]}
  ha_enabled: True
  sysctl_values:
    vm.dirty_bytes: 629145600
    vm.dirty_background_bytes: 314572800
    net.ipv4.tcp_timestamps: 0
  hana:
    host: ${sap_hana_ip}
    sid: ${sap_hana_sid}
    instance: ${sap_hana_instance}
    password: ${sap_hana_password}
  monitoring_enabled: ${enable_monitoring}
  nodes:
    - host: ${vm_names[0]}
      virtual_host: ${sap_ascs_vip_hostname}
      sid: ${sap_ascs_instance_sid}
      instance: ${sap_ascs_instance_id}
      root_user: ${sap_ascs_root_user}
      root_password: ${sap_ascs_root_password}
      saptune_solution: ${vm_saptune_solution}
      product_id: ${vm_product_id}
      sap_instance: ${vm_sap_instance}
    - host: ${vm_names[1]}
      virtual_host: ${sap_ers_vip_hostname}
      sid: ${sap_ers_instance_sid}
      instance: ${sap_ers_instance_id}
      root_user: ${sap_ers_root_user}
      root_password: ${sap_ers_root_password}
      saptune_solution: ${vm_saptune_solution}
      product_id: ${vm_product_id}
      sap_instance: ${vm_sap_instance}
EOF

# Apply patch for netweaver ha_cluster.sls
if [ "${OS_VER_MAJOR}" == "12" -o "${OS_VER_MAJOR}" == "15" ]; then
  cat <<EOF > /tmp/ha_cluster.sls.patch
--- ha_cluster.sls.orig	2022-04-20 05:26:01.615733470 +0000
+++ ha_cluster.sls	2022-04-20 05:27:54.903735510 +0000
@@ -55,25 +55,21 @@
 
 stop_sap_instance_{{ instance_name }}:
   module.run:
-    - netweaver.execute_sapcontrol:
-      - function: 'Stop'
-      - sid: {{ node.sid.lower() }}
-      - inst: {{ instance }}
-      - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
-    - test.sleep:
-      - length: 2
+    - name: netweaver.execute_sapcontrol
+    - function: 'Stop'
+    - sid: {{ node.sid.lower() }}
+    - inst: {{ instance }}
+    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
     - require:
       - netweaver_install_{{ instance_name }}
 
 stop_sap_instance_service_{{ instance_name }}:
   module.run:
-    - netweaver.execute_sapcontrol:
-      - function: 'StopService'
-      - sid: {{ node.sid.lower() }}
-      - inst: {{ instance }}
-      - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
-    - test.sleep:
-      - length: 2
+    - name: netweaver.execute_sapcontrol
+    - function: 'StopService'
+    - sid: {{ node.sid.lower() }}
+    - inst: {{ instance }}
+    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
     - require:
       - netweaver_install_{{ instance_name }}
 
@@ -144,25 +140,21 @@
 
 start_sap_instance_service_{{ instance_name }}:
   module.run:
-    - netweaver.execute_sapcontrol:
-      - function: 'StartService {{ node.sid.upper() }}'
-      - sid: {{ node.sid.lower() }}
-      - inst: {{ instance }}
-      - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
-    - test.sleep:
-      - length: 2
+    - name: netweaver.execute_sapcontrol
+    - function: 'StartService {{ node.sid.upper() }}'
+    - sid: {{ node.sid.lower() }}
+    - inst: {{ instance }}
+    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
     - require:
       - stop_sap_instance_{{ instance_name }}
 
 start_sap_instance_{{ instance_name }}:
   module.run:
-    - netweaver.execute_sapcontrol:
-      - function: 'Start'
-      - sid: {{ node.sid.lower() }}
-      - inst: {{ instance }}
-      - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
-    - test.sleep:
-      - length: 2
+    - name: netweaver.execute_sapcontrol
+    - function: 'Start'
+    - sid: {{ node.sid.lower() }}
+    - inst: {{ instance }}
+    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
     - require:
       - stop_sap_instance_{{ instance_name }}
EOF
patch --binary /usr/share/salt-formulas/states/netweaver/ha_cluster.sls /tmp/ha_cluster.sls.patch
fi

# Apply patch for netweaver install_ascs.sls
if [ "${OS_VER_MAJOR}" == "12" -o "${OS_VER_MAJOR}" == "15" ]; then
  cat <<EOF > /tmp/install_ascs.sls.patch
--- install_ascs.sls.orig	2022-04-06 11:40:18.259534554 +0000
+++ install_ascs.sls	2022-04-06 12:00:59.527526686 +0000
@@ -32,11 +32,11 @@
 {% if node.extra_parameters is defined %}
 update_ascs_inifile_{{ instance_name }}:
   module.run:
-    - netweaver.update_conf_file:
-      - conf_file: {{ inifile }}
-      - {%- for key,value in node.extra_parameters.items() %}
-        {{ key }}: "{{ value|string }}"
-        {%- endfor %}
+    - name: netweaver.update_conf_file
+    - conf_file: {{ inifile }}
+    - {%- for key,value in node.extra_parameters.items() %}
+      {{ key }}: "{{ value|string }}"
+      {%- endfor %}
 {% endif %}
 
 netweaver_install_{{ instance_name }}:
EOF
patch --binary /usr/share/salt-formulas/states/netweaver/install_ascs.sls /tmp/install_ascs.sls.patch
fi

# Apply patch for netweaver install_ers.sls
if [ "${OS_VER_MAJOR}" == "12" -o "${OS_VER_MAJOR}" == "15" ]; then
  cat <<EOF > /tmp/install_ers.sls.patch
--- install_ers.sls.orig	2022-04-06 11:40:18.259534554 +0000
+++ install_ers.sls	2022-04-06 12:01:07.575526635 +0000
@@ -32,11 +32,11 @@
 {% if node.extra_parameters is defined %}
 update_ers_inifile_{{ instance_name }}:
   module.run:
-    - netweaver.update_conf_file:
-      - conf_file: {{ inifile }}
-      - {%- for key,value in node.extra_parameters.items() %}
-        {{ key }}: "{{ value|string }}"
-        {%- endfor %}
+    - name: netweaver.update_conf_file
+    - conf_file: {{ inifile }}
+    - {%- for key,value in node.extra_parameters.items() %}
+      {{ key }}: "{{ value|string }}"
+      {%- endfor %}
 {% endif %}
 
 check_sapprofile_directory_exists_{{ instance_name }}:
EOF
patch --binary /usr/share/salt-formulas/states/netweaver/install_ers.sls /tmp/install_ers.sls.patch
fi

# Generate cluster configuration for SAP Netweaver in High Availability
echo "Preparing CIB file for SAP Netweaver in High Availability ..."
cat <<EOF > /srv/pillar/cib.config 
primitive rsc_socat_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} azure-lb \\
  params port=620${sap_ascs_instance_id} \\
  op monitor timeout=20s interval=10 depth=0
primitive rsc_socat_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} azure-lb \\
  params port=621${sap_ers_instance_id} \\
  op monitor timeout=20s interval=10 depth=0
primitive rsc_ip_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} IPaddr2 \\
  params ip=${sap_ascs_vip_address} \\
  op monitor interval=10s timeout=20s
primitive rsc_ip_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} IPaddr2 \\
  params ip=${sap_ers_vip_address} \\
  op monitor interval=10s timeout=20s
primitive rsc_exporter_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \\
  systemd:prometheus-sap_host_exporter@${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \\
  op start interval=0 timeout=100 \\
  op stop interval=0 timeout=100 \\
  op monitor interval=10 \\
  meta target-role=Started
primitive rsc_exporter_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} \\
  systemd:prometheus-sap_host_exporter@${sap_ers_instance_sid}_ERS${sap_ers_instance_id} \\
  op start interval=0 timeout=100 \\
  op stop interval=0 timeout=100 \\
  op monitor interval=10 \\
  meta target-role=Started
primitive rsc_sap_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} SAPInstance \\
  operations \$id=rsc_sap_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}-operations \\
  op monitor interval=120 timeout=60 on_fail=restart \\
  params InstanceName=${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}_${sap_ascs_vip_hostname} \\
     START_PROFILE="${sapmnt_path}/${sap_ascs_instance_sid}/profile/${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}_${sap_ascs_vip_hostname}" \\
     AUTOMATIC_RECOVER=false \\
  meta resource-stickiness=5000 failure-timeout=60 migration-threshold=1 priority=10
primitive rsc_sap_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} SAPInstance \\
  operations \$id=rsc_sap_${sap_ers_instance_sid}_ERS${sap_ers_instance_id}-operations \\
  op monitor interval=120 timeout=60 on_fail=restart \\
  params InstanceName=${sap_ers_instance_sid}_ERS${sap_ers_instance_id}_${sap_ers_vip_hostname} \\
        START_PROFILE="${sapmnt_path}/${sap_ers_instance_sid}/profile/${sap_ers_instance_sid}_ERS${sap_ers_instance_id}_${sap_ers_vip_hostname}" \\
        AUTOMATIC_RECOVER=false IS_ERS=true meta priority=1000
group grp_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \\
  rsc_ip_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \\
  rsc_sap_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \\
  rsc_socat_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \\
  rsc_exporter_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}
group grp_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} \\
  rsc_ip_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} \\
  rsc_sap_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} \\
  rsc_socat_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} \\
  rsc_exporter_${sap_ers_instance_sid}_ERS${sap_ers_instance_id}
colocation col_sap_${sap_ers_instance_sid}_no_both -5000: grp_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} \\
  grp_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}
location loc_sap_${sap_ers_instance_sid}_failover_to_ers rsc_sap_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \\
  rule 2000: runs_ers_${sap_ers_instance_sid} eq 1
order ord_sap_${sap_ers_instance_sid}_first_start_ascs Optional: rsc_sap_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}:start \\
  rsc_sap_${sap_ers_instance_sid}_ERS${sap_ers_instance_id}:stop symmetrical=false
EOF

# Remove authorized_keys file
[ -f /root/.ssh/authorized_keys ] && rm -r /root/.ssh/authorized_keys 

# Set root password
echo "Changing root password ..."
pwd=$(salt-call --local shadow.gen_password "${admin_password}" --out txt | awk '{print $2}')
salt-call --local shadow.set_password root \'${pwd}\'

# Run salt for cluster deployment
echo "Setupping cluster ..."
salt-call --local saltutil.clear_cache
salt-call --local saltutil.sync_all
salt-call --local -l debug state.apply cluster

# Wait for other node before going ahead
if [ ${vm_name} == ${vm_names[0]} ]; then
  while [ $(crm node show | grep -c "^${vm_names[1]}") -eq 0 ]; do
    echo "Waiting for ${vm_names[1]} become ready..."
    sleep 10
  done
elif [ ${vm_name} == ${vm_names[1]} ]; then
  while [ $(crm node show | grep -c "^${vm_names[0]}") -eq 0 ]; do
    echo "Waiting for ${vm_names[0]} become ready..."
    salt-call --local -l debug state.apply cluster
    sleep 10
  done
fi

# Configure stonith for Azure
if [ ${vm_name} == ${vm_names[0]} ]; then
  echo "Installing Azure STONITH ..."
  #crm configure delete admin-ip
  crm configure property maintenance-mode=true
  crm configure primitive rsc_st_azure stonith:fence_azure_arm \
    params subscriptionId="${subscription_id}" resourceGroup="${resource_group}" \
    tenantId="${tenant_id}" login="${login_id}" passwd="${app_password}" \
    pcmk_monitor_retries=4 pcmk_action_limit=3 power_timeout=900 pcmk_reboot_timeout=900 \
    op monitor interval=3600 timeout=120
  #Create Pacemaker resources for the Azure agent
  crm configure primitive rsc_azure-events ocf:heartbeat:azure-events op monitor interval=10s
  crm configure clone cln_azure-events rsc_azure-events
  crm configure property stonith-enabled=true
  crm configure property maintenance-mode=false
fi

# Run salt for SAP deployment
echo "Deployng Netweaver in High Availability ..."
crm configure property maintenance-mode=true
salt-call --local -l debug state.apply netweaver

# Configure sap exporters
echo "Configuring SAP Host Exporter in both nodes ..."
[ ! -f /etc/sap_host_exporter/${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}.yaml ] && \
  cat <<EOF > /etc/sap_host_exporter/${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}.yaml
address: ${sap_ascs_vip_hostname}
sap-control-uds: /tmp/.sapstream5${sap_ascs_instance_id}13
EOF
[ ! -f /etc/sap_host_exporter/${sap_ers_instance_sid}_ERS${sap_ers_instance_id}.yaml ] && \
  cat <<EOF > /etc/sap_host_exporter/${sap_ers_instance_sid}_ERS${sap_ers_instance_id}.yaml
address: ${sap_ers_vip_hostname}
sap-control-uds: /tmp/.sapstream5${sap_ers_instance_id}13
EOF

# Enable cluster resources on second node
echo "Bringging cluster out of maintenance ..."
if [ ${vm_name} == ${vm_names[0]} ]; then
  crm configure load update /srv/pillar/cib.config
  crm configure property maintenance-mode=false
fi

# End time
echo "End time: $(date)"
