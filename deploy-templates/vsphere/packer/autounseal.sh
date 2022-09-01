#!/bin/bash
sleep 3
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
export VAULT_TOKEN="$(cat /opt/vault/keys | grep Root | awk -F : {'print $2'} | cut -c2-)"
KEY1=`grep "Key 1" /opt/vault/keys | awk -F : '{print $2}' | cut -c2-`
KEY2=`grep "Key 2" /opt/vault/keys | awk -F : '{print $2}' | cut -c2-`
KEY3=`grep "Key 3" /opt/vault/keys | awk -F : '{print $2}' | cut -c2-`
KEY4=`grep "Key 4" /opt/vault/keys | awk -F : '{print $2}' | cut -c2-`
KEY5=`grep "Key 5" /opt/vault/keys | awk -F : '{print $2}' | cut -c2-`
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
