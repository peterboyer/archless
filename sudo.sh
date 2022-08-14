# grub

sed -i "s/GRUB_TIMEOUT=.+/GRUB_TIMEOUT=0/g" /etc/default/grub
echo "GRUB_HIDDEN_TIMEOUT=0" >> /etc/default/grub
echo "GRUB_HIDDEN_TIMEOUT_QUIET=true" >> /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg
