
sudo mkdir -pm 0755 /etc/vault.d
sudo mkdir -pm 0755 /opt/vault
sudo chown vault:vault /opt/vault

sudo mv /home/vault/autounseal.sh /etc/vault.d/autounseal.sh
chmod u+x /etc/vault.d/autounseal.sh
sudo chown vault:vault /etc/vault.d/autounseal.sh
sudo chmod +x /etc/vault.d/autounseal.sh

cat << EOF > /home/vault/vault.service
[Unit]
Description=Vault Agent
Requires=network-online.target
After=network-online.target
[Service]
Restart=on-failure
PermissionsStartOnly=true
ExecStartPre=/sbin/setcap 'cap_ipc_lock=+ep' /opt/vault/bin/vault
ExecStart=/opt/vault/bin/vault server -config /etc/vault.d/vault.hcl
ExecStartPost=/bin/bash '/etc/vault.d/autounseal.sh'
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=vault
Group=vault
[Install]
WantedBy=multi-user.target
EOF


sudo mv /home/vault/vault.service /lib/systemd/system/vault.service


cat << EOF > /home/vault/vault.hcl
storage "file" {
path = "/opt/vault"
}
listener "tcp" {
address     = "0.0.0.0:8200"
tls_disable = 1
}
ui=true
EOF

sudo mv /home/vault/vault.hcl /etc/vault.d/vault.hcl

sudo chmod 0664 /lib/systemd/system/vault.service
sudo systemctl daemon-reload
sudo chown -R vault:vault /etc/vault.d
sudo chmod -R 0644 /etc/vault.d/*

sudo systemctl enable vault
sudo systemctl start vault
sleep 60

echo "* * * * * /etc/vault.d/autounseal.sh" > /home/vault/autounseal.job

sudo mv /home/vault/autounseal.job /etc/cron.d/
sudo systemctl restart cron

cat << EOF > /home/vault/vault.sh
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
EOF

sudo mv /home/vault/vault.sh /etc/profile.d/vault.sh

cat << EOF > /home/vault/autounseal.hcl

path "transit/encrypt/autounseal" {
   capabilities = [ "update" ]
}

path "transit/decrypt/autounseal" {
   capabilities = [ "update" ]
}
EOF

cat << EOF > /home/vault/kes-policy.hcl
path "kv/*" {
     capabilities = [ "create", "read", "delete" ]
}
EOF

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
echo "Vault Init"

vault operator init > /opt/vault/keys
export VAULT_TOKEN="$(cat /opt/vault/keys | grep Root | awk -F : {'print $2'} | cut -c2-)"

echo "Unseal Vault"

sudo bash /etc/vault.d/autounseal.sh

echo "Confuration vault"
vault secrets enable transit
vault secrets enable kv
vault auth enable approle
vault policy write kes-policy /home/vault/kes-policy.hcl
vault write auth/approle/role/kes-role token_num_uses=0  secret_id_num_uses=0  period=5m
vault write auth/approle/role/kes-role policies=kes-policy
vault read auth/approle/role/kes-role/role-id
vault write -f auth/approle/role/kes-role/secret-id

vault write -f transit/keys/autounseal
vault policy write autounseal /home/vault/autounseal.hcl
vault token create -policy="autounseal" -wrap-ttl=120 > /opt/vault/token
