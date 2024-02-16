#!/usr/bin/env bash

function pause(){
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
pause

# Mounting targets
mount "${ROOT}" /mnt
mount --mkdir "${EFI}" /mnt/boot
swapon "${SWAP}"
pause

# Mirror update
reflector --country Brazil --latest 10 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist
pause

# Pacstrap the base and base-devel with usual dependencies
if [[ $WIFI_OPT == '1' ]]
then
  pacstrap -K /mnt base base-devel linux linux-firmware nano git man-db texinfo networkmanager wpa_supplicant bash-completion grub os-prober efibootmgr
else
  pacstrap -K /mnt base base-devel linux linux-firmware nano git man-db texinfo networkmanager bash-completion grub os-prober efibootmgr
fi
pause

# fstab
genfstab -U /mnt >> /mnt/etc/fstab
pause

# Script part to run inside chroot
#######################################################################
cat <<CHROOT > /mnt/chroot.sh

function pause(){
  read -t 6
}

# Sets the timezone
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
pause

# Generates /etc/adjtime
hwclock --systohc
pause

# Setting the locale
echo "en_GB.UTF-8 UTF-8" > /ect/locale.gen
echo "pt_BR.UTF-8 UTF-8" >> /ect/locale.gen
pause

cat /etc/locale.gen
pause

locale-gen
pause

echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf
pause

# Hostname
echo "$HOST" > /etc/hostname

# Enable Network Manager amd set-up Wifi
#systemctl enable NetworkManager.service
#systemctl start NetworkManager.service
#if [[ $WIFI_OPT == '1' ]]
#then
#  nmcli device wifi connect "$SSID" password #"$WIFI_PASS"
#else
#  echo "No Wifi to set-up"
#fi

# Root password
echo root:$ROOT_PASSWORD | chpasswd
pause

# Adding the normal user with sudo abilities
useradd -m -G wheel,storage,power,audio -s /bin/bash $USERNAME
echo $USERNAME:$USER_PASSWORD | chpasswd
pause

# Enable sudo for wheel users
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
pause

# GRUB install
## Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
pause

## Enables GRUB os-prober
sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

## Generates the GRUB config
grub-mkconfig -o /boot/grub/grub.cfg
pause

CHROOT
#######################################################################

# Change root
arch-chroot /mnt sh chroot.sh
