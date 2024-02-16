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
read HOSTNAME
echo "Enter the username: "
read USER
echo "Enter the user password: "
read USER_PASSWORD

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
pacstrap -K /mnt base base-devel linux linux-firmware nano git man-db texinfo networkmanager wpa_supplicant bash-completion grub os-probe efibootmgr

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

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

#CHROOT

# Change root
arch-chroot /mnt sh chroot.sh
