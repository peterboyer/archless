PACKAGES=(
  htop
  pulseaudio
  pulsemixer
  xorg
  xorg-xinit
  xwallpaper
  alacritty
  ttf-jetbrains-mono
  bspwm
  sxhkd
  dmenu
  polybar
)

# https://github.com/Jguer/yay

if [[ "$(which yay; echo $?);" != "0" ]]; then
  (
    cd $HOME;
    git clone https://aur.archlinux.org/yay-bin.git;
    cd yay-bin;
    yes | makepkg -si --noconfirm;
    rm -rf $HOME/yay-bin;
  )
fi

# https://wiki.archlinux.org/title/Font_configuration#Fontconfig_configuration

mkdir -p $HOME/.config/fontconfig
cat << EOF > $HOME/.config/fontconfig/fonts.conf
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrains Mono</family>
    </prefer>
  </alias>
</fontconfig>
EOF
