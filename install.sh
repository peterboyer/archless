#!/bin/env bash

set -x
set -e

# if /env doesn't exist yet, then we are outside arch-chroot /mnt
if [[ ! -e "/env" ]]; then

# if set, will load script that exports options for install
#   - <USER> --> resolve to raw.githubusercontent.com/<USER>/dotfiles/main/archless
#   - <USER>/<REPO> --> resolve to raw.githubusercontent.com/<USER>/<REPO>/main/archless
#   - otherwise, use as-is (can be any url)
export oPROFILE=${oPROFILE:-$PROFILE}

# if set, will git clone from given http[s]://.../*.git repo and execute scripts[1]
#   - <USER> --> resolve to https://github.com/<USER>/dotfiles.git
#   - <USER>/<REPO> --> resolve to https://github.com/<USER>/<REPO>.git
#   - otherwise, use as-is (can be any url)
# [1] scripts:
#   - /sudo.sh (any root system changes as root user)
#   - /user.sh (any changes as non-root user)
export oDOTFILES=${oDOTFILES:-"*"}

# target device to install system
export oDEV=${oDEV:-${DEV:-"*"}}
export oDEV_BOOT
export oDEV_SWAP
export oDEV_ROOT

# name of machine (for /etc/hostname and /etc/hosts)
export oHOST=${oHOST:-arch}

# name of non-root user
export oUSER=${oUSER:-admin}

# timezone from available /zoneinfo/**/* to be linked to /etc/localtime
export oTZ=${oTZ:-UTC}

# language from available /etc/locale.gen
export oLANG=${oLANG:-en_US}

# keymap from available keymaps/**/* to be loaded via loadkeys
export oKEYMAP=${oKEYMAP:-us}

# filesystem to use for root partition, as with mkfs.*
export oFS=${oFS:-btrfs}

# size of swap partition
#   - 0 --> no swap partition
#   - 1..n --> 1..n GB sized partition
#   - memory --> use size of available memory as size of swap
export oSWAP=${oSWAP:-memory}

# install ucode package when doing pacstrap
#   - auto --> automatically determine intel or amd from lscpu output
#   - intel/amd --> force specific ucode package
#   - none --> skip
export oUCODE=${oUCODE:-auto}

# set partition scheme
#   - auto --> automatically determine from boot mode via ../efivars dir
#   - mbr/gpt --> force specific partiton scheme
export oSCHEME=${oSCHEME:-auto}

# profile/dotfiles

zPROFILE=$oPROFILE
if [[ -n "$oPROFILE" ]]; then
  if [[ "$oPROFILE" =~ ^[a-zA-Z]+$ ]]; then
    oPROFILE="https://raw.githubusercontent.com/$oPROFILE/dotfiles/main/archless"
  elif [[ "$oPROFILE" =~ ^[a-zA-Z]+\/[.a-zA-Z]+$ ]]; then
    oPROFILE="https://raw.githubusercontent.com/$oPROFILE/main/archless"
  fi
  curl "$oPROFILE" -o ./profile
  source ./profile
  rm ./profile
fi

if [[ "$oDOTFILES" == "*" ]]; then
  oDOTFILES=$zPROFILE;
fi

if [[ -n "$oDOTFILES" ]]; then
  if [[ "$oDOTFILES" =~ ^[a-zA-Z]+$ ]]; then
    oDOTFILES="https://github.com/$oDOTFILES/dotfiles.git"
  elif [[ "$DOTFILES" =~ ^[a-zA-Z]+\/[.a-zA-Z]+$ ]]; then
    oDOTFILES="https://github.com/$oDOTFILES.git"
  fi
fi

# devices

if [[ "$oDEV" == "*" ]]; then
  export oDEV="/dev/$(lsblk | grep -E 'disk $' | awk '{ print $1 }')"
fi

# https://wiki.archlinux.org/title/Installation_guide#Verify_the_boot_mode

if [[ "$oSCHEME" == "auto" ]]; then
  oSCHEME="mbr"
  if [[ -d /sys/firmware/efi/efivars ]]; then
    oSCHEME="gpt"
  fi
fi

# swap

if [[ "$oSWAP" == "memory" ]]; then
  oSWAP="$(free --giga | grep Mem | awk '{ print $2 }')"
fi

# partitions

INDEX=1; next() { INDEX=$((INDEX+1)); }
PREFIX=""
if [[ -n "$(echo $oDEV | grep nvme)" ]]; then PREFIX="p"; fi

if [[ "$oSCHEME" == "gpt" ]]; then oDEV_BOOT="$oDEV$PREFIX$INDEX"; next; fi
if [[ "$oSWAP" != "0" ]]; then oDEV_SWAP="$oDEV$PREFIX$INDEX"; next; fi
oDEV_ROOT="$oDEV$PREFIX$INDEX"; next;

# microcode

if [[ "$oUCODE" == "auto" ]]; then
  if [[ -n "$(lscpu | grep GenuineIntel)" ]]; then
    oUCODE="intel"
  elif [[ -n "$(lscpu | grep AuthenticAMD)" ]]; then
    oUCODE="amd"
  fi
fi

env | grep -E '^o'

read -p "archless: press <enter> to confirm ..." sure

# https://wiki.archlinux.org/title/Installation_guide#Update_the_system_clock

timedatectl set-ntp true

# https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks

(
  if [[ "$oSCHEME" == "mbr" ]]; then echo o; fi
  if [[ "$oSCHEME" == "gpt" ]]; then echo g; fi

  # boot
  if [[ "$oSCHEME" == "gpt" ]]; then
    echo n; echo; echo; echo +300M;
    echo t; echo 1; echo 1;
  fi

  # swap
  if [[ "$oSWAP" != "0" ]]; then
    if [[ "$oSCHEME" == "mbr" ]]; then echo n; echo; echo; echo; echo +${oSWAP}G; fi
    if [[ "$oSCHEME" == "gpt" ]]; then echo n; echo; echo; echo +${oSWAP}G; fi
    echo t; echo 2; echo 19; fi

  # root
  if [[ "$oSCHEME" == "mbr" ]]; then echo n; echo; echo; echo; echo; fi
  if [[ "$oSCHEME" == "gpt" ]]; then echo n; echo; echo; echo; fi

  echo w;
) | fdisk $oDEV --wipe always --wipe-partitions always

# https://wiki.archlinux.org/title/Installation_guide#Format_the_partitions

if [[ -n "$oDEV_BOOT" ]]; then mkfs.fat -F 32 $oDEV_BOOT; fi
if [[ -n "$oDEV_SWAP" ]]; then mkswap $oDEV_SWAP; fi
mkfs.$oFS -f $oDEV_ROOT

# https://wiki.archlinux.org/title/Installation_guide#Mount_the_file_systems

mount --mkdir $oDEV_ROOT /mnt
if [[ -n "$oDEV_BOOT" ]]; then mount --mkdir $oDEV_BOOT /mnt/boot; fi
if [[ -n "$oDEV_SWAP" ]]; then swapon $oDEV_SWAP; fi

# https://wiki.archlinux.org/title/Installation_guide#Fstab

mkdir -p /mnt/etc
genfstab -U /mnt > /mnt/etc/fstab

# https://bbs.archlinux.org/viewtopic.php?pid=2033301#p2033301

yes | pacman -Sy --noconfirm archlinux-keyring

# https://wiki.archlinux.org/title/Installation_guide#Select_the_mirrors

reflector || true

# https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages

UCODE=""
if [[ "$oUCODE" == "intel" || "$oUCODE" == "amd" ]]; then
  UCODE="$oUCODE-ucode"
fi

yes | pacstrap /mnt \
  base base-devel \
  linux linux-firmware $UCODE \
  grub efibootmgr \
  networkmanager \
  sof-firmware \
  git

# https://wiki.archlinux.org/title/Installation_guide#Chroot

# copy environment options
env | grep -E '^o' > /mnt/env

# copy ./install.sh script into /mnt
cp $0 /mnt

# chroot
arch-chroot /mnt

fi # --continue

source /env

# https://wiki.archlinux.org/title/Installation_guide#Time_zone

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

if [[ "$oSCHEME" == "mbr" ]]; then grub-install --target=i386-pc $oDEV; fi
if [[ "$oSCHEME" == "gpt" ]]; then
  set +e
  mkinitcpio -P
  set -e

  mkdir -p /boot/EFI
  mount $oDEV_BOOT /boot/EFI
  grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/EFI \
    --bootloader-id=arch \
    --recheck
fi
grub-mkconfig -o /boot/grub/grub.cfg

# dotfiles

git clone $oDOTFILES /home/$oUSER/_dotfiles
chown -R $oUSER:$oUSER /home/$oUSER/_dotfiles
