#/bin/env bash

set -ex
if [[ $USER != "root" ]]; then
  echo "Not 'root' user. Are you sure you're running this in a fresh Arch environment?"
  exit
fi

# overrides
CONFIG_HOSTNAME="bear"
CONFIG_PASSWORD="root"
CONFIG_USERNAME=$CONFIG_HOSTNAME
CONFIG_PARTIONTABLE="mbr" # "mbr" or "gpt"
CONFIG_PARTIONDEVICE="sda" # "sda" or "nvme0n1"
CONFIG_SWAPMEMORY=1 # size of memory in GBs (swap = memory + 1)

bootsize=300M
swapsize=18G
dev=/dev/nvme0n1
devboot=/dev/nvme0n1p1
devswap=/dev/nvme0n1p2
devroot=/dev/nvme0n1p3
if [[ $vm == "true" ]]; then
  swapsize=2G
  dev=/dev/sda
  devboot=/dev/sda1
  devswap=/dev/sda2
  devroot=/dev/sda3
fi

cat << EOF > temp.sh
function STEP() {
  echo;
  echo "##### \$1 #####"
  echo;
}
export CONFIG_HOSTNAME=$CONFIG_HOSTNAME
export CONFIG_PASSWORD=$CONFIG_PASSWORD
export CONFIG_USERNAME=$CONFIG_USERNAME
export dev=$dev
export -f STEP
EOF

source ./temp.sh

PATH_ROOT=/mnt
PATH_BOOT=/mnt/boot

STEP partion
if [[ $CONFIG_PARTIONTABLE == "mbr" ]]; then
  if [[ -n "$(lsblk | grep "/mnt")" ]]; then
    umount $PATH_BOOT # boot
    umount $PATH_ROOT # root
    swapoff -a       # swap
  fi

  (
    echo M; # dos/mbr
    echo n; echo; echo; echo "+$(expr $CONFIG_SWAPMEMORY + 1)G"; # swap
    echo n; echo; echo; echo;                                    # root
    echo w;
  ) | fdisk $dev &>/dev/null
elif [[ $CONFIG_PARTIONTABLE == "gpt" ]]; then
  (
    echo g; # gpt
    echo n; echo; echo; echo +300M;                              # boot
    echo n; echo; echo; echo "+$(expr $CONFIG_SWAPMEMORY + 1)G"; # swap
    echo n; echo; echo; echo;                                    # root
    echo w;
  ) | fdisk $dev &>/dev/null
fi

lsblk

if [[ $CONFIG_PARTIONDEVICE == "sda" ]]; then
  DEV_BOOT=
fi
DEV_ROOT=""

STEP format
mkfs.btrfs -f $devroot  &>/dev/null # root
mkfs.fat -F 32 $devboot &>/dev/null # boot
mkswap $devswap         &>/dev/null # swap

if [[ -z "$(lsblk | grep "/mnt")" ]]; then
  STEP mount
  mount --mkdir $devroot $PATH_ROOT # root
  mount --mkdir $devboot $PATH_BOOT # boot
  swapon $devswap                  # swap
fi
lsblk

if false; then
STEP mirrors
reflector

STEP pacstrap
pacstrap $PATH_ROOT \
  base base-devel linux linux-firmware sof-firmware \
  grub efibootmgr networkmanager

STEP fstab
genfstab -U $PATH_ROOT >> $PATH_ROOT/etc/fstab
fi

STEP chroot
arch-chroot $PATH_ROOT
source ./temp.sh

if false; then
STEP ntclock
timedatectl set-ntp true

STEP timeszone
ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime

STEP hwclock
hwclock --systohc

STEP localisation
sed -i 's/#en_AU.UTF-8/en_AU.UTF-8/g' /etc/locale.gen
locale-gen
echo "LANG=en_AU.UTF-8" > /etc/locale.conf

STEP CONFIG_HOSTNAME
echo $CONFIG_HOSTNAME > /etc/CONFIG_HOSTNAME

STEP rootpwd
chpasswd <<< "root:$CONFIG_PASSWORD"

STEP user
if [[ -z "$(cat /etc/passwd | grep $CONFIG_USERNAME)" ]]; then
  useradd -m -G wheel -s /bin/bash $CONFIG_USERNAME
fi
chpasswd <<< "$CONFIG_USERNAME:$CONFIG_PASSWORD"

STEP sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
fi

STEP services
systemctl enable NetworkManager

STEP grub
grub-install $dev
