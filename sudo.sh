# grub

(
  cd /etc/default;
  ln -fs /home/$oUSER/config/grub;
  grub-mkconfig -o /boot/grub/grub.cfg
)
