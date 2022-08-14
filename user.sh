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

# ensure .config dir

mkdir -p ~/.config

# https://wiki.archlinux.org/title/Font_configuration#Fontconfig_configuration

(
  cd ~/.config;
  ln -fs ../.dotfiles/.config/fontconfig;
)
