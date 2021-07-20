#!/usr/bin/env bash

logger "Install prerequisites"

apt-get update && apt-get install -y unzip libtool libltdl-dev || logger "Installation of the prerequisites has failed"

USER="vault"
GROUP="vault"
COMMENT="Hashicorp vault user"

HOME="/srv/vault"

# Detect package management system.
APT_GET=$(which apt-get 2>/dev/null)


user_ubuntu() {
# UBUNTU user setup
  if ! getent group $${GROUP} >/dev/null
  then
    sudo addgroup --system $${GROUP} >/dev/null
  fi

  if ! getent passwd $${USER} >/dev/null
  then
    sudo adduser \
    --system \
    --disabled-login \
    --ingroup $${GROUP} \
    --home $${HOME} \
    --no-create-home \
    --gecos "$${COMMENT}" \
    --shell /bin/false \
    $${USER}  >/dev/null
  fi
}

  if [[ ! -z $${APT_GET} ]]; then
  logger "Setting up user $${USER} for Debian/Ubuntu"
  user_ubuntu
  else
    logger "$${USER} user not created due to OS detection failure"
    exit 1;
  fi

logger "User setup complete"

logger "Mount ebs volume ${vault_volume_mount_path} into ${vault_local_mount_path}"

VAULT_VOLUME_FS=`blkid -o value -s TYPE ${vault_volume_mount_path}`
if [[ -z $${VAULT_VOLUME_FS} ]] ; then
  if cat /etc/fstab | grep "${vault_volume_mount_path} ${vault_local_mount_path}" > /dev/null ; then
    logger "The volume ${vault_volume_mount_path} already mounted to ${vault_local_mount_path}. No formating required."
  else
    logger "Formating the volume ${vault_volume_mount_path}."
    mkfs.xfs ${vault_volume_mount_path}
  fi
fi
if [[ -d ${vault_local_mount_path} ]] ; then
  logger "The mount point directory ${vault_local_mount_path} already exist"
else
  logger "Creating mount point directory ${vault_local_mount_path}"
  mkdir -p ${vault_local_mount_path}
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
  mount ${vault_local_mount_path} || logger "Mounting volume ${vault_volume_mount_path} to point ${vault_local_mount_path} has been failed"
  chown $${USER}:$${GROUP} ${vault_local_mount_path}
fi

logger "Initialazing vault configuration prerequisites"
VAULT_ZIP="vault.zip"
VAULT_URL="${vault_url}"
curl --silent --output /tmp/$${VAULT_ZIP} $${VAULT_URL}
unzip -o /tmp/$${VAULT_ZIP} -d /usr/local/bin/
chmod 0755 /usr/local/bin/vault
chown $${USER}:$${GROUP} /usr/local/bin/vault
mkdir -pm 0755 /etc/vault.d
mkdir -pm 0755 "${vault_local_mount_path}/vault"
chown $${USER}:$${GROUP} "${vault_local_mount_path}/vault"

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
User=$${USER}
Group=$${GROUP}
[Install]
WantedBy=multi-user.target
EOF

if [[ ! -d "${vault_local_mount_path}/letsencrypt/live/${vault_domain}" ]] && [[ ! -n $(ls -A ${vault_local_mount_path}/letsencrypt/archive/${vault_domain}/{fullchain*,privkey*}.pem) ]] ; then
  sudo apt-get update
  sudo apt-get install software-properties-common -y
  sudo add-apt-repository ppa:certbot/certbot -y
  sudo apt-get update
  sudo apt-get install certbot -y
  sleep 10
  sudo certbot certonly --standalone -d "${vault_domain}" --register-unsafely-without-email --agree-tos
  sleep 30
  sudo cp -r "/etc/letsencrypt" "${vault_local_mount_path}"
  sudo chmod -R 755 "${vault_local_mount_path}/letsencrypt/live/" && sudo chmod -R 755 "${vault_local_mount_path}/letsencrypt/archive/"
fi


logger "Configuring Vault"
cat << EOF > /etc/vault.d/vault.hcl
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


sudo chmod 0664 /lib/systemd/system/vault.service
systemctl daemon-reload
sudo chown -R $${USER}:$${GROUP} /etc/vault.d
sudo chmod -R 0644 /etc/vault.d/*

cat << EOF > /etc/profile.d/vault.sh
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
EOF
logger "Configuring Encryption policy"
cat << EOF > /home/ubuntu/autounseal.hcl

path "transit/encrypt/autounseal" {
   capabilities = [ "update" ]
}

path "transit/decrypt/autounseal" {
   capabilities = [ "update" ]
}
EOF

cat << EOF > /home/ubuntu/kes-policy.hcl
path "kv/*" {
     capabilities = [ "create", "read", "delete" ]
}
EOF
logger "Starting Vault service"
systemctl enable vault
systemctl start vault
sleep 60
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
if [ ! -f "${vault_local_mount_path}/vault/token" ]; then
  logger "Initializing Vault"
  vault operator init > "${vault_local_mount_path}/vault/keys"
  export VAULT_TOKEN="$(cat ${vault_local_mount_path}/vault/keys | grep Root | awk -F : {'print $2'} | cut -c2-)"
  vault secrets enable transit

  vault secrets enable kv
  vault auth enable approle
  vault policy write kes-policy /home/ubuntu/kes-policy.hcl
  vault write auth/approle/role/kes-role token_num_uses=0  secret_id_num_uses=0  period=5m
  vault write auth/approle/role/kes-role policies=kes-policy
  vault read auth/approle/role/kes-role/role-id
  vault write -f auth/approle/role/kes-role/secret-id

  vault write -f transit/keys/autounseal
  vault policy write autounseal /home/ubuntu/autounseal.hcl
  vault token create -policy="autounseal" -wrap-ttl=120 > "${vault_local_mount_path}/vault/token"
fi

systemctl is-active vault && touch /tmp/signal