#!/usr/bin/env bash

terraform init && terraform apply -auto-approve

pass_generator() {
  for ((n=0;n<1;n++)); do
    dd if=/dev/urandom count=1 2> /dev/null | uuencode -m - | sed -ne 2p | cut -c-12
  done
}

SSH_USERNAME="mdtuddm"
SSH_PASSWORD=$(pass_generator)

cat << EOF > ./SSH-creds
username: ${SSH_USERNAME}
password: ${SSH_PASSWORD}
EOF

cat << EOF > ./preseed.cfg
# Preseeding only locale sets language, country and locale.
d-i debian-installer/locale string en_US.UTF-8

# Keyboard selection.
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/xkb-keymap select us

choose-mirror-bin mirror/http/proxy string

# Avoid that last message about the install being complete.
d-i finish-install/reboot_in_progress note

# This is fairly safe to set, it makes grub install automatically to the MBR
# if no other operating system is detected on the machine.
d-i grub-installer/only_debian boolean true

# This one makes grub-installer install to the MBR if it also finds some other
# OS, which is less safe as it might not be able to boot that other OS.
d-i grub-installer/with_other_os boolean true

### Mirror settings
# If you select ftp, the mirror/country string does not need to be set.
d-i mirror/country string manual
d-i mirror/http/directory string /ubuntu/
d-i mirror/http/hostname string archive.ubuntu.com
d-i mirror/http/proxy string

### Partitioning
d-i partman-auto/method string lvm
d-i partman-lvm/device_remove_lvm boolean true

# This makes partman automatically partition without confirmation.
d-i partman-md/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

### Account setup
d-i passwd/user-fullname string ${SSH_USERNAME}
d-i passwd/user-uid string 1000
d-i passwd/user-password password ${SSH_PASSWORD}
d-i passwd/user-password-again password ${SSH_PASSWORD}
d-i passwd/username string ${SSH_USERNAME}

# The installer will warn about weak passwords. If you are sure you know
# what you're doing and want to override it, uncomment this.
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

### Package selection
tasksel tasksel/first standard
d-i pkgsel/include string openssh-server nfs-common open-vm-tools build-essential
d-i pkgsel/install-language-support boolean false

# disable automatic package updates
d-i pkgsel/update-policy select none
d-i pkgsel/upgrade select full-upgrade

d-i preseed/late_command string \
    echo '${SSH_USERNAME} ALL=(ALL) NOPASSWD: ALL' > /target/etc/sudoers.d/${SSH_USERNAME} ; \
    in-target chmod 440 /etc/sudoers.d/${SSH_USERNAME} ;
EOF

packer build -force\
    -var vsphere_server="${VSPHERE_SERVER}" \
    -var vsphere_user="${VSPHERE_USER}" \
    -var vsphere_password="${VSPHERE_PASSWORD}" \
    -var vsphere_datacenter="${VSPHERE_DATACENTER}" \
    -var vsphere_resource_pool="${VSPHERE_RESOURCE_POOL}" \
    -var vsphere_folder="${VSPHERE_FOLDER}" \
    -var vsphere_cluster="${VSPHERE_CLUSTER}" \
    -var vsphere_datastore="${VSPHERE_DATASTORE}" \
    -var vsphere_network="${VSPHERE_NETWORK}" \
    -var ssh_username="${SSH_USERNAME}" \
    -var ssh_password="${SSH_PASSWORD}" \
    .
