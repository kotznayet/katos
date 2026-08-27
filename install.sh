#!/bin/bash

### Script setup

set -euo pipefail
if [ -z "${STY:-}" ]; then
    sudo apt update
    sudo apt install -y screen
    exec screen -S katos_install bash -c 'bash <(curl -fsSL https://raw.githubusercontent.com/kotznayet/katos/main/install.sh)'
fi

### Base system

sudo apt upgrade -y
sudo apt install -y --no-install-recommends \
  wget curl git zsh tmux unzip \
  python3 python3-pip python3-venv \
  nodejs npm btop toilet \
  plasma-desktop plasma-workspace kwin-wayland xwayland \
  plasma-nm bluedevil dolphin konsole kate kdialog \
  vlc kde-spectacle ark filelight systemsettings powerdevil \
  plasma-pa kscreen plasma-integration plasma-browser-integration \
  kwalletmanager kde-cli-tools partitionmanager \
  pipewire pipewire-jack wireplumber \
  rpi-eeprom exfatprogs nmap kcalc \
  command-not-found yt-dlp ffmpeg libglu1-mesa


### Remove everyting unneeded

sudo systemctl disable --now cloud-init.service cloud-init-local.service \
  cloud-config.service cloud-final.service 2>/dev/null || true
sudo systemctl mask cloud-init.service cloud-init-local.service \
  cloud-config.service cloud-final.service 2>/dev/null || true
sudo apt purge -y cloud-init htop || true
sudo rm -rf /etc/cloud /var/lib/cloud
sudo systemctl disable --now NetworkManager-wait-online.service \
  systemd-networkd-wait-online.service 2>/dev/null || true


### Wayland environment

mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/wayland.conf <<EOF
QT_QPA_PLATFORM=wayland
XDG_CURRENT_DESKTOP=KDE
MOZ_ENABLE_WAYLAND=1
EOF


### Pi-Apps

if [ ! -d "$HOME/pi-apps" ]; then
  git clone https://github.com/Botspot/pi-apps.git "$HOME/pi-apps"
  "$HOME/pi-apps/install"
fi
"$HOME/pi-apps/manage" install "More RAM"
"$HOME/pi-apps/manage" install "Zen"
"$HOME/pi-apps/manage" install "Persepolis Download Manager"
"$HOME/pi-apps/manage" install "VSCodium"


### uBlock Origin

ZEN_PROFILE=$(find "$HOME/.zen" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n1)
if [ -n "$ZEN_PROFILE" ]; then
  mkdir -p "$ZEN_PROFILE/extensions"
  wget -qO "$ZEN_PROFILE/extensions/uBlock0@raymondhill.net.xpi" \
    'https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi'
fi


### Launch KDE

grep -q startplasma-wayland ~/.profile 2>/dev/null || cat >> ~/.profile <<'EOF'

if [[ "$(tty)" == "/dev/tty1" && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
  clear
  toilet --metal katos
  startplasma-wayland
fi
EOF


### ZSH in Konsole

mkdir -p ~/.local/share/konsole
cat > ~/.local/share/konsole/zsh.profile <<EOF
[General]
Name=zsh
Command=/usr/bin/zsh
EOF
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile zsh.profile


### CascadiaCode Font

TMP_FONT=$(mktemp -d)
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/CascadiaCode.zip \
  -O "$TMP_FONT/font.zip"
unzip -q "$TMP_FONT/font.zip" -d "$TMP_FONT"
mkdir -p ~/.local/share/fonts
cp "$TMP_FONT"/*.ttf ~/.local/share/fonts/
fc-cache -f
rm -rf "$TMP_FONT"


### VSCodium settings

mkdir -p ~/.config/VSCodium/User

cat > ~/.config/VSCodium/User/settings.json <<EOF
{
  "editor.fontFamily": "CascadiaCode Nerd Font, monospace",
  "editor.fontLigatures": true,
  "terminal.integrated.fontFamily": "CascadiaCode Nerd Font",
  "window.titleBarStyle": "native",
  "window.menuBarVisibility": "compact",
  "window.menuStyle": "custom"
}
EOF

cat > ~/.config/VSCodium/User/argv.json <<EOF
{
  "ozone-platform": "wayland",
  "enable-features": "UseOzonePlatform",
  "disable-gpu-sandbox": true
}
EOF

### Disable lock
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false

### PipeWire low latency

mkdir -p ~/.config/pipewire/pipewire.conf.d
cat > ~/.config/pipewire/pipewire.conf.d/low-latency.conf <<EOF
context.properties = {
  default.clock.rate = 48000
  default.clock.min-quantum = 64
  default.clock.max-quantum = 128
}
EOF

### Breeze Dark

kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
plasma-apply-lookandfeel org.kde.breezedark.desktop || true


### Autologin tty1

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF


### Powerlevel10k

touch ~/.zshrc
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k || true
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc

sudo rm -f /var/swap

echo "=================================================="
echo " SETUP COMPLETE — REBOOTING"
echo "=================================================="

sudo reboot
