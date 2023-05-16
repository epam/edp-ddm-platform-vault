#!/usr/bin/env bash

USER="vault"
GROUP="vault"
HOME="/srv/vault"

# Detect package management system.
APT_GET=$(which apt-get 2>/dev/null)

echo 'nameserver 8.8.8.8' | tee /etc/resolv.conf >/dev/null

apt update >/dev/null
apt install -y unzip libtool libltdl-dev sharutils curl jq software-properties-common xfsprogs >/dev/null

user_ubuntu() {
# UBUNTU user setup
  if ! getent group ${GROUP} >/dev/null
  then
    addgroup --system ${GROUP} >/dev/null
  fi

  if ! getent passwd ${USER} >/dev/null
  then
    adduser \
    --system \
    --disabled-login \
    --ingroup ${GROUP} \
    --home ${HOME} \
    --no-create-home \
    --shell /bin/false \
    ${USER}  >/dev/null
  fi
}

if [[ ! -z ${APT_GET} ]]; then
  logger "Setting up user ${USER} for Debian/Ubuntu"
  user_ubuntu
else
    logger "${USER} user not created due to OS detection failure"
    exit 1;
fi

logger "User setup complete"

logger "Mount ebs volume ${vault_volume_path} into ${vault_local_mount_path}"

VAULT_VOLUME_FS=`blkid -o value -s TYPE ${vault_volume_path}`
if [[ -z ${VAULT_VOLUME_FS} ]] ; then
  if cat /etc/fstab | grep "${vault_volume_path} ${vault_local_mount_path}" > /dev/null ; then
    logger "The volume ${vault_volume_path} already mounted to ${vault_local_mount_path}. No formatting required."
  else
    logger "Formatting the volume ${vault_volume_path}."
    mkfs.xfs ${vault_volume_path}
  fi
fi
if [[ -d ${vault_local_mount_path} ]] ; then
  logger "The mount point directory ${vault_local_mount_path} already exist"
else
  logger "Creating mount point directory ${vault_local_mount_path}"
  mkdir -p ${vault_local_mount_path}
fi

# check if exist in fstab and then mount if not already mounted
if cat /etc/fstab | grep ${vault_volume_path}; then
  logger "Device ${vault_volume_path} is present in /etc/fstab"
else
  logger "Adding ${vault_volume_path} to /etc/fstab"
  echo "${vault_volume_path} ${vault_local_mount_path} xfs defaults 0 0" | sudo  tee -a /etc/fstab
fi

if mount | grep ${vault_volume_path} ; then
  logger "Mounting point ${vault_volume_path} is already mounted"
else
  logger "Mounting ${vault_local_mount_path}"
  mount ${vault_local_mount_path} || logger "Mounting volume ${vault_volume_path} to point ${vault_local_mount_path} has been failed"
  chown ${USER}:${GROUP} ${vault_local_mount_path}
fi

logger "Initializing vault configuration prerequisites"
VAULT_ZIP="vault.zip"
VAULT_URL="${vault_url}"
curl --silent --output /tmp/${VAULT_ZIP} ${VAULT_URL}
unzip -o /tmp/${VAULT_ZIP} -d /usr/local/bin/
chmod 0755 /usr/local/bin/vault
chown ${USER}:${GROUP} /usr/local/bin/vault
mkdir -pm 0755 /etc/vault.d
mkdir -pm 0755 "${vault_local_mount_path}/vault"
chown ${USER}:${GROUP} "${vault_local_mount_path}/vault"

logger "Creating Vault service"
cat << EOF > /lib/systemd/system/vault.service
[Unit]
Description=Vault Agent
Requires=network-online.target
After=network-online.target
[Service]
Restart=on-failure
PermissionsStartOnly=true
ExecStartPre=/sbin/setcap 'cap_ipc_lock=+ep' /usr/local/bin/vault
ExecStart=/usr/local/bin/vault server -config /etc/vault.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=${USER}
Group=${GROUP}
[Install]
WantedBy=multi-user.target
EOF

logger "Configuring Vault"
cat << EOF > /etc/vault.d/vault.hcl
storage "file" {
path = "${vault_local_mount_path}/vault"
}
listener "tcp" {
address     = "0.0.0.0:8200"
tls_disable = 1
}
ui=true
EOF


sudo chmod 0664 /lib/systemd/system/vault.service
systemctl daemon-reload
sudo chown -R ${USER}:${GROUP} /etc/vault.d
sudo chmod -R 0644 /etc/vault.d/*

cat << EOF > /etc/profile.d/vault.sh
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
EOF
logger "Configuring Encryption policy"
cat << EOF > /etc/vault.d/autounseal.hcl

path "transit/encrypt/autounseal" {
   capabilities = [ "update" ]
}

path "transit/decrypt/autounseal" {
   capabilities = [ "update" ]
}
EOF

cat << EOF > /etc/vault.d/kes-policy.hcl
path "kv/*" {
     capabilities = [ "create", "read", "delete" ]
}
EOF
logger "Starting Vault service"
systemctl enable vault
systemctl restart vault
