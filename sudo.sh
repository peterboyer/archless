# https://wiki.archlinux.org/title/GRUB#Configuration

(
  cd /etc/default;
  ln -fs /home/$oUSER/config/grub;
  grub-mkconfig -o /boot/grub/grub.cfg
)
