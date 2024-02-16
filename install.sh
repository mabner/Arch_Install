#!/usr/bin/env bash

# Input parameters
echo "Enter the patch to the EFI partition: "
read EFI
echo "Enter the path to the ROOT partition: "
read ROOT
echo "Enter the path to the SWAP partition: "
read SWAP
echo "Enter the ROOT password"
read ROOT_PASSWORD
echo "Enter the HOSTNAME: "
read HOST
echo "Enter the username: "
read USERNAME
echo "Enter the user password: "
read USER_PASSWORD
echo "Set-up Wifi? (Any* - No / 1 - Yes)"
read WIFI_OPT
if [[ $WIFI_OPT == '1' ]]
then
  echo "Enter the Wifi SSID: "
  read SSID
  echo "Enter the Wifi password"
  read WIFI_PASS
else
  echo "No Wifi to set-up"
fi

# Setting the filesystem
echo -e "\nFormating partitions\n"
mkfs.ext4 "${ROOT}" -L "Arch"
mkswap "${SWAP}" -L "Swap"

# Mounting targets
mount "${ROOT}" /mnt
mount --mkdir "${EFI}" /mnt/boot
swapon "${SWAP}"

# Mirror update
reflector --country Brazil --latest 10 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist

# Pacstrap the base and base-devel with usual dependencies
if [[ $WIFI_OPT == '1' ]]
then
  pacstrap -K /mnt base base-devel linux linux-firmware nano git man-db texinfo networkmanager wpa_supplicant bash-completion grub os-probe efibootmgr
else
  pacstrap -K /mnt base base-devel linux linux-firmware nano git man-db texinfo networkmanager bash-completion grub os-probe efibootmgr
fi

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Stops iwctl in order to run nmcli inside chroot
systemctl stop iwd.service

# Script part to run inside chroot
#cat <<CHROOT > /mnt/chroot.sh

# Sets the timezone
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# Generates /etc/adjtime
hwclock --systohc

# Setting the locale
echo "en_GB.UTF-8 UTF-8" > /ect/locale.gen
echo "pt_BR.UTF-8 UTF-8" >> /ect/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf

# Hostname
echo "${HOST}" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	"$HOST".localdomain	"$HOST"
EOF

# Enable Network Manager amd set-up Wifi
systemctl enable NetworkManager.service
systemctl start NetworkManager.service
if [[ $WIFI_OPT == '1' ]]
then
  nmcli device wifi connect "${SSID}" password "${WIFI_PASS}"
else
  echo "No Wifi to set-up"
fi

#CHROOT

# Change root
arch-chroot /mnt sh chroot.sh
