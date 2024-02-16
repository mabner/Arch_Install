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





