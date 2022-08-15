#!/bin/env bash

set -x
set -e

export oHOST=${oHOST:-arch}
export oUSER=${oUSER:-admin}
export oTZ=${oTZ:-UTC}
export oLANG=${oLANG:-en_US}
export oKEYMAP=${oKEYMAP:-us}
export oFS=${oFS:-btrfs}
export oSWAP=${oSWAP:-memory}
export oUCODE=${oUCODE:-auto}

# https://wiki.archlinux.org/title/Installation_guide#Verify_the_boot_mode

vSCHEME="mbr"
if [[ -d /sys/firmware/efi/efivars ]]; then
  vSCHEME="gpt"
fi

# https://wiki.archlinux.org/title/Installation_guide#Update_the_system_clock

timedatectl set-ntp true

# https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks

vDEV="/dev/$(lsblk | grep disk | awk '{ print $1 }')"

if [[ "$oSWAP" == "memory" ]]; then
  oSWAP="$(free --giga | grep Mem | awk '{ print $2 }')"
fi

(
  if [[ "$vSCHEME" == "mbr" ]]; then echo o; fi
  if [[ "$vSCHEME" == "gpt" ]]; then echo g; fi

  if [[ "$vSCHEME" == "gpt" ]]; then echo n; echo; echo; echo +300M; fi

  if [[ "$vSCHEME" == "mbr" && "$oSWAP" != "0" ]]; then echo n; echo; echo; echo; echo +${oSWAP}G; fi
  if [[ "$vSCHEME" == "gpt" && "$oSWAP" != "0" ]]; then echo n; echo; echo; echo +${oSWAP}G; fi

  if [[ "$vSCHEME" == "mbr" && "$oSWAP" != "0" ]]; then echo n; echo; echo; echo; echo; fi
  if [[ "$vSCHEME" == "gpt" && "$oSWAP" != "0" ]]; then echo n; echo; echo; echo; fi

  echo w;
) | fdisk $vDEV --wipe always --wipe-partitions always &> /dev/null

# https://wiki.archlinux.org/title/Installation_guide#Format_the_partitions

INDEX=1
PREFIX=""
if [[ -n "$(echo $vDEV | grep nvme)" ]]; then
  PREFIX="p"
fi

if [[ "$vSCHEME" == "gpt" ]]; then
  vDEV_BOOT="$vDEV$PREFIX$INDEX"; INDEX=$((INDEX+1));
  mkfs.fat -F 32 $vDEV_BOOT
fi

if [[ "$oSWAP" != "0" ]]; then
  vDEV_SWAP="$vDEV$PREFIX$INDEX"; INDEX=$((INDEX+1));
  mkswap $vDEV_SWAP
fi

vDEV_ROOT="$vDEV$PREFIX$INDEX"; INDEX=$((INDEX+1));
mkfs.$oFS -f $vDEV_ROOT

# https://wiki.archlinux.org/title/Installation_guide#Mount_the_file_systems

mount --mkdir $vDEV_ROOT /mnt
if [[ "$vSCHEME" == "gpt" ]]; then mount --mkdir $vDEV_BOOT /mnt/boot; fi
if [[ "$oSWAP" != "0" ]]; then swapon $vDEV_SWAP; fi

# https://wiki.archlinux.org/title/Installation_guide#Fstab

mkdir -p /mnt/etc
genfstab -U /mnt > /mnt/etc/fstab

# https://bbs.archlinux.org/viewtopic.php?pid=2033301#p2033301

yes | pacman -Sy --noconfirm archlinux-keyring

# https://wiki.archlinux.org/title/Installation_guide#Select_the_mirrors

reflector || true

# https://wiki.archlinux.org/title/Microcode#Installation

UCODE=""
if [[ "$oUCODE" == "auto" ]]; then
  if [[ -n "$(lscpu | grep GenuineIntel)" ]]; then
    UCODE="intel-ucode"
  elif [[ -n "$(lscpu | grep AuthenticAMD)" ]]; then
    UCODE="amd-ucode"
  fi
elif [[ "$oUCODE" == "intel" ]]; then
  UCODE="intel-ucode"
elif [[ "$oUCODE" == "amd" ]]; then
  UCODE="amd-ucode"
fi

# https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages

yes | pacstrap /mnt \
  base base-devel \
  linux linux-firmware $UCODE \
  grub efibootmgr \
  networkmanager \
  sof-firmware \
  git

# https://wiki.archlinux.org/title/Installation_guide#Chroot

env | grep -E '^o' > /mnt/env
echo "vDEV=$vDEV" >> /mnt/env
echo "vSCHEME=$vSCHEME" >> /mnt/env

arch-chroot /mnt

source /env

# https://wiki.archlinux.org/title/Installation_guide#Time_zone

# TODO: verify that this actually persists ntp config into new install
timedatectl set-ntp true

ln -sf /usr/share/zoneinfo/$oTZ /etc/localtime
hwclock --systohc

# https://wiki.archlinux.org/title/Installation_guide#Set_the_console_keyboard_layout

loadkeys $oKEYMAP

# https://wiki.archlinux.org/title/Installation_guide#Localization

sed -i "s/#$oLANG.UTF-8/$oLANG.UTF-8/g" /etc/locale.gen
locale-gen

echo "LANG=$oLANG.UTF-8" > /etc/locale.conf
echo "KEYMAP=$oKEYMAP" > /etc/vconsole.conf

# https://wiki.archlinux.org/title/Installation_guide#Network_configuration

echo "$oHOST" > /etc/hostname

echo "::1        localhost" >> /etc/hosts
echo "127.0.0.1  localhost" >> /etc/hosts
echo "127.0.1.1  $oHOST.localdomain $oHOST" >> /etc/hosts

systemctl enable NetworkManager

# https://wiki.archlinux.org/title/Installation_guide#Root_password

chpasswd <<< "root:password"

# https://wiki.archlinux.org/title/Users_and_groups#User_management

useradd -mG wheel $oUSER
chpasswd <<< "$oUSER:password"
sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g" /etc/sudoers

# https://wiki.archlinux.org/title/Installation_guide#Boot_loader

if [[ "$vSCHEME" == "mbr" ]]; then grub-install --target=i386-pc $vDEV; fi
if [[ "$vSCHEME" == "gpt" ]]; then grub-install --target $vDEV; fi

grub-mkconfig -o /boot/grub/grub.cfg

# dotfiles

(
  su $oUSER;
  git clone $oDOTFILES $HOME/.dotfiles;
)

# sudo.sh

(
  cd /home/$oUSER/.dotfiles;
  ./sudo.sh;
)

# temp enable (disable below)
sed -i "s/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g" /etc/sudoers

# switch

su $oUSER

# user.sh

(
  cd /home/$oUSER/.dotfiles;
  ./user.sh;
)

# root

exit

# cleanup /env

rm /env

# disable nopasswd

sed -i "s/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g" /etc/sudoers
