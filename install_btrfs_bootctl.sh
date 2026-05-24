#!/usr/bin/env bash
set -e

pause_install() {
  read -t 6 || true
}

echo "----------------"
echo "Input parameters"
echo "----------------"
echo "Enter the path to the EFI partition: "
read EFI
if [[ ! -b "$EFI" ]]; then
  echo "Error: EFI partition '$EFI' is not a valid block device."
  exit 1
fi

echo "Enter the path to the ROOT partition: "
read ROOT
if [[ ! -b "$ROOT" ]]; then
  echo "Error: ROOT partition '$ROOT' is not a valid block device."
  exit 1
fi

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
mkfs.btrfs -f "${ROOT}" -L "arch"
pause_install

echo "----------------"
echo "Mounting targets"
echo "----------------"
mount "${ROOT}" /mnt

echo "-------------------"
echo "Creating subvolumes"
echo "-------------------"
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
pause_install
umount /mnt
pause_install

echo "------------------"
echo "Mouting subvolumes"
echo "------------------"
mount -o compress=zstd,noatime,subvol=@ "${ROOT}" /mnt
mkdir -p /mnt/{boot,home,.snapshots}
mount -o compress=zstd,noatime,subvol=@home "${ROOT}" /mnt/home
mount -o compress=zstd,noatime,subvol=@snapshots "${ROOT}" /mnt/.snapshots
mount "${EFI}" /mnt/boot
pause_install

echo "-------------"
echo "Mirror update"
echo "-------------"
reflector --country Brazil --latest 10 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist
pause_install

echo "--------------------------------------------------------"
echo "Pacstrap the base and base-devel with usual dependencies"
echo "--------------------------------------------------------"
PACKAGES=(
  base base-devel linux linux-firmware
  nano git bash-completion
  man-db texinfo
  networkmanager
  btrfs-progs
  pipewire pipewire-pulse wireplumber
  mesa
  noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono
)

[[ $WIFI_OPT == '1' ]] && PACKAGES+=(wpa_supplicant)

pacstrap -K /mnt "${PACKAGES[@]}"
pause_install

echo "----------------"
echo "Generating fstab"
echo "----------------"
genfstab -U /mnt >> /mnt/etc/fstab
pause_install

ROOT_UUID=$(blkid -s UUID -o value "$ROOT")

# Script part to run inside chroot
#######################################################################
arch-chroot /mnt /bin/bash <<CHROOT

set -e

pause_install() {
  read -t 6 || true
}

echo "-----------------"
echo "Sets the timezone"
echo "-----------------"
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
pause_install

echo "----------------------"
echo "Generates /etc/adjtime"
echo "----------------------"
hwclock --systohc
pause_install

echo "------------------"
echo "Setting the locale"
echo "------------------"
sed -i 's/^#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
pause_install

locale-gen
pause_install

echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf
pause_install

echo "--------"
echo "Hostname"
echo "--------"
echo "$HOST" > /etc/hostname

cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOST.localdomain $HOST
HOSTS


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
pause_install

echo "------------------------------------------"
echo "Adding the normal user with sudo abilities"
echo "------------------------------------------"
useradd -m -G wheel,storage,power,audio -s /bin/bash $USERNAME
echo $USERNAME:$USER_PASSWORD | chpasswd
pause_install

echo "---------------------------"
echo "Enable sudo for wheel users"
echo "---------------------------"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
pause_install

echo "----------"
echo "Bootloader"
echo "----------"
bootctl install

cat > /boot/loader/loader.conf <<LOADER

default arch
timeout 3
editor no

LOADER

cat > /boot/loader/entries/arch.conf <<ENTRY
title Arch Linux
linux /vmlinuz-linux
#initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=UUID=$ROOT_UUID rootflags=subvol=@ rw

ENTRY

echo "--------------------------------------"
echo "Enable Network Manager and set-up Wifi"
echo "--------------------------------------"
systemctl enable NetworkManager

if [[ $WIFI_OPT == '1' ]]
then
  CONN_UUID=\$(cat /proc/sys/kernel/random/uuid)
  mkdir -p /etc/NetworkManager/system-connections
  cat > "/etc/NetworkManager/system-connections/$SSID.nmconnection" <<EOF
[connection]
id=$SSID
uuid=\$CONN_UUID
type=wifi

[wifi]
mode=infrastructure
ssid=$SSID

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$WIFI_PASS

[ipv4]
method=auto

[ipv6]
method=auto
EOF
  chmod 600 "/etc/NetworkManager/system-connections/$SSID.nmconnection"
else
  echo "No Wifi to set-up"
fi
pause_install

CHROOT


echo "-------------_-------"
echo "Unmounting partitions"
echo "-------_-------------"
umount -R /mnt

echo "--------------------"
echo "Instalation finished"
echo "  Ready to reboot   "
echo "--------------------"
