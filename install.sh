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
swapon "${SWAP}"

# Mounting targets
mount "${ROOT} /mnt"
mkdir /mnt/boot
mount "${EFI} /mnt/boot"


