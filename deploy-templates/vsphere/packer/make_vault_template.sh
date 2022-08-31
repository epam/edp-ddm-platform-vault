#!/usr/bin/env bash

terraform init && terraform apply -auto-approve

pass_generator() {
for ((n=0;n<1;n++))
do dd if=/dev/urandom count=1 2> /dev/null | uuencode -m - | sed -ne 2p | cut -c-12
done
}

SSH_PASSWORD=$(pass_generator)

cat << EOF > ./preseed.cfg
# Setting the locales, country
# Supported locales available in /usr/share/i18n/SUPPORTED
d-i debian-installer/language string en
d-i debian-installer/country string us
d-i debian-installer/locale string en_US.UTF-8

# Keyboard setting
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/layoutcode string us
d-i keyboard-configuration/xkb-keymap us
d-i keyboard-configuration/modelcode string pc105

# Disk and Partitioning setup
d-i partman-auto/disk string /dev/sda
d-i partman-auto/method string regular
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

d-i passwd/user-fullname string vault
d-i passwd/username string vault
d-i passwd/user-password password ${SSH_PASSWORD}
d-i passwd/user-password-again password ${SSH_PASSWORD}
d-i user-setup/allow-password-weak boolean true

d-i passwd/root-login boolean false
d-i passwd/root-password-encrypted password !

d-i pkgsel/include string open-vm-tools openssh-server cloud-init
d-i grub-installer/only_debian boolean true

d-i preseed/late_command string \
    echo 'vault ALL=(ALL) NOPASSWD: ALL' > /target/etc/sudoers.d/vault ; \
    in-target chmod 440 /etc/sudoers.d/vault ;

d-i finish-install/reboot_in_progress note
EOF

packer build -force \
    -var-file=variables.json \
    -var vsphere_server="${VSPHERE_SERVER}" \
    -var vsphere_user="${VSPHERE_USER}" \
    -var vsphere_password="${VSPHERE_PASSWORD}" \
    -var vsphere_cluster="${VSPHERE_CLUSTER}" \
    -var vsphere_network="${VSPHERE_NETWORK}" \
    -var vsphere_datastore="${VSPHERE_DATASTORE}" \
    -var vsphere_datacenter="${VSPHERE_DATACENTER}" \
    -var ssh_password="${SSH_PASSWORD}" \
    packer.json