#!/usr/bin/env bash

UNSEAL_VAULT() {
  logger "Unsealing Vault"
  export VAULT_TOKEN="$(cat ${vault_local_mount_path}/vault/keys | grep Root | awk -F : {'print $2'} | cut -c2-)"
  KEY1=`grep "Key 1" ${vault_local_mount_path}/vault/keys  | awk -F : '{print $2}' | cut -c2-`
  KEY2=`grep "Key 2" ${vault_local_mount_path}/vault/keys  | awk -F : '{print $2}' | cut -c2-`
  KEY3=`grep "Key 3" ${vault_local_mount_path}/vault/keys  | awk -F : '{print $2}' | cut -c2-`
  KEY4=`grep "Key 4" ${vault_local_mount_path}/vault/keys  | awk -F : '{print $2}' | cut -c2-`
  KEY5=`grep "Key 5" ${vault_local_mount_path}/vault/keys  | awk -F : '{print $2}' | cut -c2-`
  vault_status=$(vault status -format "json" | jq --raw-output '.sealed')

  if [[ $vault_status == 'false' ]]; then
    :
  elif [[ $vault_status == 'true' ]]; then
    keys=(${KEY1} ${KEY2} ${KEY3} ${KEY4} ${KEY5})
    i=1
    while [[ $vault_status == 'true' ]];
            do
            vault operator unseal ${keys[$i]}
            vault_status=$(vault status -format "json" | jq --raw-output '.sealed')
            i=$[$i+1]
    done
  else
    :
  fi
}

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true

if [ -f "${vault_local_mount_path}/vault/keys" ]; then
  UNSEAL_VAULT
fi

if [ ! -f "${vault_local_mount_path}/vault/token" ]; then
  logger "Initializing Vault"
  vault operator init > "${vault_local_mount_path}/vault/keys"

  UNSEAL_VAULT

  vault secrets enable transit
  vault secrets enable kv
  vault auth enable approle
  vault policy write kes-policy /etc/vault.d/kes-policy.hcl
  vault write auth/approle/role/kes-role token_num_uses=0  secret_id_num_uses=0  period=5m
  vault write auth/approle/role/kes-role policies=kes-policy
  vault read auth/approle/role/kes-role/role-id
  vault write -f auth/approle/role/kes-role/secret-id

  vault write -f transit/keys/autounseal
  vault policy write autounseal /etc/vault.d/autounseal.hcl
  vault token create -policy="autounseal" -wrap-ttl=120 > "${vault_local_mount_path}/vault/token"
fi

systemctl is-active vault && touch /tmp/signal
