#!/bin/env bash

# TODO: set-ntp for new install (via. arch-chroot?)
# TODO: get password from user input

set -x
set -e

# OPTIONS

oNTP=${oNTP:-true}
oSWAP=${oSWAP:-memory}
oFS=${oFS:-btrfs}
oUCODE=${oUCODE:-auto}
oTZ=${oTZ:-UTC}
oLANG=${oLANG:-en_US}
oHOST=${oHOST:-arch}
oUSER=${oUSER:-admin}
oKEYMAP=${oKEYMAP:-us}

# PARTITIONS

DEV="/dev/$(lsblk | grep disk | awk '{ print $1 }')"

SCHEME="mbr"
if [[ -d /sys/firmware/efi/efivars ]]; then
  SCHEME="gpt"
fi

if [[ "$oSWAP" == "memory" ]]; then
  oSWAP="$(free --giga | grep Mem | awk '{ print $2 }')"
fi

(
  if [[ "$SCHEME" == "mbr" ]]; then echo o; fi
  if [[ "$SCHEME" == "gpt" ]]; then echo g; fi

  if [[ "$SCHEME" == "gpt" ]]; then echo n; echo; echo; echo +300M; fi

  if [[ "$SCHEME" == "mbr" && "$oSWAP" != "0" ]]; then echo n; echo; echo; echo; echo +${oSWAP}G; fi
  if [[ "$SCHEME" == "gpt" && "$oSWAP" != "0" ]]; then echo n; echo; echo; echo +${oSWAP}G; fi

  if [[ "$SCHEME" == "mbr" && "$oSWAP" != "0" ]]; then echo n; echo; echo; echo; echo; fi
  if [[ "$SCHEME" == "gpt" && "$oSWAP" != "0" ]]; then echo n; echo; echo; echo; fi

  echo w;
) | fdisk $DEV --wipe always --wipe-partitions always &> /dev/null

# FILESYSTEMS

INDEX=1
PREFIX=""
if [[ -n "$(echo $DEV | grep nvme)" ]]; then
  PREFIX="p"
fi

if [[ "$SCHEME" == "gpt" ]]; then
  DEV_BOOT="$DEV$PREFIX$INDEX"; INDEX=$((INDEX+1));
  mkfs.fat -F 32 $DEV_BOOT
fi

if [[ "$oSWAP" != "0" ]]; then
  DEV_SWAP="$DEV$PREFIX$INDEX"; INDEX=$((INDEX+1));
  mkswap $DEV_SWAP
fi

DEV_ROOT="$DEV$PREFIX$INDEX"; INDEX=$((INDEX+1));
mkfs.$oFS -f $DEV_ROOT

# mount

mount --mkdir $DEV_ROOT /mnt
if [[ "$SCHEME" == "gpt" ]]; then mount --mkdir $DEV_BOOT /mnt/boot; fi
if [[ "$oSWAP" != "0" ]]; then swapon $DEV_SWAP; fi

# config

mkdir -p /mnt/etc
genfstab -U /mnt > /mnt/etc/fstab

# PACKAGES

if [[ "$oNTP" == "true" ]]; then
  timedatectl set-ntp true
fi

reflector || true

# keys

yes | pacman -Sy --noconfirm archlinux-keyring

# microcode

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

# install

yes | pacstrap /mnt \
  base base-devel linux linux-firmware $UCODE \
  grub efibootmgr networkmanager sof-firmware

# ROOT

echo "export oTZ=$oTZ" >> /mnt/env
echo "export oLANG=$oLANG" >> /mnt/env
echo "export oKEYMAP=$oKEYMAP" >> /mnt/env
echo "export oHOST=$oHOST" >> /mnt/env
echo "export oUSER=$oUSER" >> /mnt/env

echo "export DEV=$DEV" >> /mnt/env
echo "export SCHEME=$SCHEME" >> /mnt/env

arch-chroot /mnt

source /env

# CLOCK

ln -sf /usr/share/zoneinfo/$oTZ /etc/localtime
hwclock --systohc

# LOCALISATION

sed -i 's/#$oLANG.UTF-8/$oLANG.UTF-8/g' /etc/locale.gen
locale-gen
echo "LANG=$oLANG.UTF-8" > /etc/locale.conf

loadkeys $oKEYMAP
echo "KEYMAP=$oKEYMAP" > /etc/vconsole.conf

# HOSTNAME

echo "$oHOST" > /etc/hostname

# hosts

echo "::1        localhost" >> /etc/hosts
echo "127.0.0.1  localhost" >> /etc/hosts
echo "127.0.1.1  $oHOST.localdomain $oHOST" >> /etc/hosts

# NETWORK

systemctl enable NetworkManager

# GRUB

if [[ "$SCHEME" == "mbr" ]]; then grub-install --target=i386-pc $DEV; fi
if [[ "$SCHEME" == "gpt" ]]; then grub-install --target $DEV; fi

grub-mkconfig -o /boot/grub/grub.cfg

# USERS

# root

chpasswd <<< "root:password"

# user

useradd -mG wheel $oUSER
chpasswd <<< "$oUSER:password"

# sudoers

sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
