#!/usr/bin/env bash

USER="vault"
GROUP="vault"

logger "Mount ebs volume ${vault_volume_mount_path} into ${vault_local_mount_path}"
VAULT_VOLUME_FS=`blkid -o value -s TYPE ${vault_volume_mount_path}`
if [[ -z $${VAULT_VOLUME_FS} ]] ; then
  if cat /etc/fstab | grep "${vault_volume_mount_path} ${vault_local_mount_path}" > /dev/null ; then
    logger "The volume ${vault_volume_mount_path} already mounted to ${vault_local_mount_path}. No formating required."
  else
    logger "Formating the volume ${vault_volume_mount_path}."
    sudo mkfs.xfs ${vault_volume_mount_path}
  fi
fi
if [[ -d ${vault_local_mount_path} ]] ; then
  logger "The mount point directory ${vault_local_mount_path} already exist"
else
  logger "Creating mount point directory ${vault_local_mount_path}"
  sudo mkdir -p ${vault_local_mount_path}
fi

# check if exist in fstab and then mount if not already mounted
if cat /etc/fstab | grep ${vault_volume_mount_path}; then
  logger "Device ${vault_volume_mount_path} is present in /etc/fstab"
else
  logger "Adding ${vault_volume_mount_path} to /etc/fstab"
  echo "${vault_volume_mount_path} ${vault_local_mount_path} xfs defaults 0 0" | sudo  tee -a /etc/fstab
fi

if mount | grep ${vault_volume_mount_path} ; then
  logger "Mounting point ${vault_volume_mount_path} is already mounted"
else
  logger "Mounting ${vault_local_mount_path}"
  sudo mount ${vault_local_mount_path} || logger "Mounting volume ${vault_volume_mount_path} to point ${vault_local_mount_path} has been failed"
  sudo chown $${USER}:$${GROUP} ${vault_local_mount_path}
fi

logger "Lookup vault token"

if [[ -f /opt/vault/token ]] ; then
  logger "The Vault is already initialized"

  if ! [[ -d "${vault_local_mount_path}/backup" ]] ; then
    sudo mkdir -p "${vault_local_mount_path}/backup"

    logger "Backuping direcotry /etc/vault.d"
    sudo cp -rp /etc/vault.d "${vault_local_mount_path}/backup/"

    logger "Backuping direcotry /opt/vault"
    sudo cp -rp /opt/vault "${vault_local_mount_path}/backup/"

    logger "Backuping direcotry /etc/letsencrypt"
    sudo cp -rp /etc/letsencrypt "${vault_local_mount_path}/backup/"
  else
    if ! [[ -d ${vault_local_mount_path}/backup/vault.d ]] ; then 
      logger "Backuping direcotry /etc/vault.d"
      sudo cp -rp /etc/vault.d "${vault_local_mount_path}/backup/"
    fi
    if ! [[ -d ${vault_local_mount_path}/backup/vault ]] ; then 
      logger "Backuping direcotry /opt/vault"
      sudo cp -rp /opt/vault "${vault_local_mount_path}/backup/"
    fi
    if ! [[ -d ${vault_local_mount_path}/backup/letsencrypt ]] ; then 
      logger "Backuping direcotry /opt/vault"
      sudo cp -rp /etc/letsencrypt "${vault_local_mount_path}/backup/"
    fi
  fi

  if [[ -f "${vault_local_mount_path}/vault/token" ]] && $(grep -E "^path = \"${vault_local_mount_path}/vault\"$" /etc/vault.d/vault.hcl) && $(systemctl is-active vault) ; then
    logger "Vault is pointed to EBS"
  else
    logger "Moving vault data from /opt/vault to ebs mount point ${vault_local_mount_path}/vault"
    sudo cp -rp /opt/vault "${vault_local_mount_path}/"
  
    logger "Updating /etc/vault.d/vault.hcl"
    sudo chmod 666 /etc/vault.d/vault.hcl \
    && sudo cat << EOF > /etc/vault.d/vault.hcl
storage "file" {
path = "${vault_local_mount_path}/vault"
}
listener "tcp" {
address     = "0.0.0.0:8200"
tls_disable = 0
tls_cert_file = "/etc/letsencrypt/live/${vault_domain}/fullchain.pem"
tls_key_file  = "/etc/letsencrypt/live/${vault_domain}/privkey.pem"
}
seal "awskms" {
region     = "${aws_region}"
kms_key_id = "${kms_key}"
}
ui=true
EOF

    sudo chown -R $${USER}:$${GROUP} /etc/vault.d
    sudo chmod -R 0644 /etc/vault.d/*
    sudo systemctl daemon-reload
    sudo systemctl restart vault
  fi
fi

if [[ -d "${vault_local_mount_path}/letsencrypt/live/${vault_domain}" ]] && [[ -n $(ls -A ${vault_local_mount_path}/letsencrypt/archive/${vault_domain}/{fullchain*,privkey*}.pem) ]] ; then

  sudo cp -r "/etc/letsencrypt" "${vault_local_mount_path}/"
  sudo chmod -R 755 "${vault_local_mount_path}/letsencrypt/live/" && sudo chmod -R 755 "${vault_local_mount_path}/letsencrypt/archive/"

  logger "Updating /etc/vault.d/vault.hcl"
  sudo chmod 666 /etc/vault.d/vault.hcl \
  && sudo cat << EOF > /etc/vault.d/vault.hcl
storage "file" {
path = "${vault_local_mount_path}/vault"
}
listener "tcp" {
address     = "0.0.0.0:8200"
tls_disable = 0
tls_cert_file = "${vault_local_mount_path}/letsencrypt/live/${vault_domain}/fullchain.pem"
tls_key_file  = "${vault_local_mount_path}/letsencrypt/live/${vault_domain}/privkey.pem"
}
seal "awskms" {
region     = "${aws_region}"
kms_key_id = "${kms_key}"
}
ui=true
EOF

  sudo chown -R $${USER}:$${GROUP} /etc/vault.d
  sudo chmod -R 0644 /etc/vault.d/*
  sudo systemctl daemon-reload
  sudo systemctl restart vault

fi