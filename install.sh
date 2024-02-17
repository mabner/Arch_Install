#!/usr/bin/env bash

function read -t 6(){
  read -t 6
}

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
read -t 6

# Mounting targets
mount "${ROOT}" /mnt
mount --mkdir "${EFI}" /mnt/boot
swapon "${SWAP}"
read -t 6

# Mirror update
reflector --country Brazil --latest 10 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist
read -t 6

# Pacstrap the base and base-devel with usual dependencies
if [[ $WIFI_OPT == '1' ]]
then
  pacstrap -K /mnt base base-devel linux linux-firmware nano git man-db texinfo networkmanager wpa_supplicant bash-completion grub os-prober efibootmgr
else
  pacstrap -K /mnt base base-devel linux linux-firmware nano git man-db texinfo networkmanager bash-completion grub os-prober efibootmgr
fi
read -t 6

# fstab
genfstab -U /mnt >> /mnt/etc/fstab
read -t 6

# Script part to run inside chroot
#######################################################################
#cat <<CHROOT > /mnt/chroot.sh

# Sets the timezone
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
read -t 6

# Generates /etc/adjtime
hwclock --systohc
read -t 6

# Setting the locale
sed -i 's/^#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
read -t 6

cat /etc/locale.gen
read -t 6

locale-gen
read -t 6

echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf
read -t 6

# Hostname
echo "$HOST" > /etc/hostname

# Config colours, simultaneous downloads and multilib in Pacman
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 4/' /etc/pacman.conf
sed -i 's/^#[multilib]/[multilib]/' /etc/pacman.conf
sed -i 's/^#Include = /etc/pacman.d/mirrorlist/Include = /etc/pacman.d/mirrorlist/' /etc/pacman.conf


# Root password
echo root:$ROOT_PASSWORD | chpasswd
read -t 6

# Adding the normal user with sudo abilities
useradd -m -G wheel,storage,power,audio -s /bin/bash $USERNAME
echo $USERNAME:$USER_PASSWORD | chpasswd
read -t 6

# Enable sudo for wheel users
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
read -t 6

# GRUB install
## Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
read -t 6

## Enables GRUB os-prober
sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

## Generates the GRUB config
grub-mkconfig -o /boot/grub/grub.cfg
read -t 6

CHROOT
#######################################################################

# Script to run after install to enable NetworkManager and set-up Wifi
#cat <<POST_INSTALL > /mnt/post_install.sh

rm /chroot.sh

# Enable Network Manager amd set-up Wifi
if [[ $WIFI_OPT == '1' ]]
then
  systemctl enable NetworkManager.service
  systemctl start NetworkManager.service
  nmcli device wifi connect "$SSID" password "$WIFI_PASS"
else
  echo "No Wifi to set-up"
fi

#POST_INSTALL

# Change root
arch-chroot /mnt sh chroot.sh
