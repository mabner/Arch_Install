#!/usr/bin/env bash

echo "----------------"
echo "Input parameters"
echo "----------------"
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

echo "----------------------"
echo "Setting the filesystem"
echo "----------------------"
echo -e "\nFormating partitions\n"
mkfs.ext4 "${ROOT}" -L "Arch"
mkswap "${SWAP}" -L "Swap"
read -t 6

echo "----------------"
echo "Mounting targets"
echo "----------------"
mount "${ROOT}" /mnt
mount --mkdir "${EFI}" /mnt/boot
swapon "${SWAP}"
read -t 6

echo "-------------"
echo "Mirror update"
echo "-------------"
reflector --country Brazil --latest 10 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist
read -t 6

echo "--------------------------------------------------------"
echo "Pacstrap the base and base-devel with usual dependencies"
echo "--------------------------------------------------------"
if [[ $WIFI_OPT == '1' ]]
then
  pacstrap -K /mnt base base-devel linux linux-firmware nano git man-db texinfo networkmanager wpa_supplicant bash-completion
else
  pacstrap -K /mnt base base-devel linux linux-firmware nano git man-db texinfo networkmanager bash-completion
fi
read -t 6

echo "----------------"
echo "Generating fstab"
echo "----------------"
genfstab -U /mnt >> /mnt/etc/fstab
read -t 6

# Script part to run inside chroot
#######################################################################
cat <<CHROOT > /mnt/chroot.sh
echo "-----------------"
echo "Sets the timezone"
echo "-----------------"
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
read -t 6

echo "----------------------"
echo "Generates /etc/adjtime"
echo "----------------------"
hwclock --systohc
read -t 6

echo "------------------"
echo "Setting the locale"
echo "------------------"
sed -i 's/^#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
read -t 6

locale-gen
read -t 6

echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf
read -t 6

echo "--------"
echo "Hostname"
echo "--------"
echo "$HOST" > /etc/hostname

echo "-------------------------------------------------------------"
echo "Config colours, simultaneous downloads and multilib in Pacman"
echo "-------------------------------------------------------------"
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 4/' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

echo "-------------"
echo "Root password"
echo "-------------"
echo root:$ROOT_PASSWORD | chpasswd
read -t 6

echo "------------------------------------------"
echo "Adding the normal user with sudo abilities"
echo "------------------------------------------"
useradd -m -G wheel,storage,power,audio -s /bin/bash $USERNAME
echo $USERNAME:$USER_PASSWORD | chpasswd
read -t 6

echo "---------------------------"
echo "Enable sudo for wheel users"
echo "---------------------------"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
read -t 6


CHROOT
#######################################################################

# Script to run after install to enable NetworkManager and set-up Wifi
cat <<POST_INSTALL > /mnt/post_install.sh
rm /chroot.sh
echo "--------------------------------------"
echo "Enable Network Manager amd set-up Wifi"
echo "--------------------------------------"
if [[ $WIFI_OPT == '1' ]]
then
  systemctl enable NetworkManager.service
  systemctl start NetworkManager.service
  read -t 10
  nmcli device wifi
  nmcli device wifi connect "$SSID" password "$WIFI_PASS"
else
  echo "No Wifi to set-up"
fi

rm /post_install.sh
read -t 6
POST_INSTALL

# Change root
arch-chroot /mnt sh chroot.sh
