#!/bin/bash

### ==================================================
### Base system
### ==================================================
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y --no-install-recommends \
  wget curl git zsh tmux unzip \
  python3 python3-pip python3-venv \
  nodejs npm btop \
  plasma-desktop plasma-workspace kwin-wayland xwayland \
  plasma-nm bluedevil dolphin konsole kate kdialog \
  vlc kde-spectacle ark filelight  systemsettings powerdevil \
  plasma-pa kscreen plasma-integration plasma-browser-integration \
  kwalletmanager kde-cli-tools partitionmanager \
  pipewire pipewire-jack wireplumber \
  rpi-eeprom exfatprogs nmap kcalc \
  command-not-found yt-dlp ffmpeg 

### ==================================================
### Kill cloud-init and remove htop
### ==================================================
sudo systemctl disable --now cloud-init.service cloud-init-local.service \
  cloud-config.service cloud-final.service 2>/dev/null || true
sudo systemctl mask cloud-init.service cloud-init-local.service \
  cloud-config.service cloud-final.service 2>/dev/null || true
sudo apt purge -y cloud-init htop || true
sudo rm -rf /etc/cloud /var/lib/cloud

### ==================================================
### Kill wait-online delays
### ==================================================
sudo systemctl disable --now NetworkManager-wait-online.service \
  systemd-networkd-wait-online.service 2>/dev/null || true

### ==================================================
### Wayland environment
### ==================================================
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/wayland.conf <<EOF
QT_QPA_PLATFORM=wayland
XDG_CURRENT_DESKTOP=KDE
MOZ_ENABLE_WAYLAND=1
EOF

### ==================================================
### Pi-Apps (no desktop shortcuts)
### ==================================================
if [ ! -d "$HOME/pi-apps" ]; then
  git clone https://github.com/Botspot/pi-apps.git "$HOME/pi-apps"
  "$HOME/pi-apps/install"
fi
"$HOME/pi-apps/manage" install "More RAM"
"$HOME/pi-apps/manage" install "Zen"
"$HOME/pi-apps/manage" install "Persepolis Download Manager"
"$HOME/pi-apps/manage" install "VSCodium"
### ==================================================
### tty1 → Plasma Wayland
### ==================================================
grep -q startplasma-wayland ~/.profile 2>/dev/null || cat >> ~/.profile <<'EOF'

if [[ "$(tty)" == "/dev/tty1" && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
  exec startplasma-wayland
  zsh
fi
EOF

### ==================================================
### Konsole → zsh
### ==================================================
mkdir -p ~/.local/share/konsole
cat > ~/.local/share/konsole/zsh.profile <<EOF
[General]
Name=zsh
Command=/usr/bin/zsh
EOF
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile zsh.profile

### ==================================================
### CascadiaCode Nerd Font
### ==================================================
TMP_FONT=$(mktemp -d)
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/CascadiaCode.zip \
  -O "$TMP_FONT/font.zip"
unzip -q "$TMP_FONT/font.zip" -d "$TMP_FONT"
mkdir -p ~/.local/share/fonts
cp "$TMP_FONT"/*.ttf ~/.local/share/fonts/
fc-cache -f
rm -rf "$TMP_FONT"

### ==================================================
### VS Code settings + Electron Wayland
### ==================================================
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
### ------------------------------------------
### Disable lock behavior
### ------------------------------------------
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnStartup false

### ------------------------------------------
### Screen turns off after 10 minutes, no lock
### ------------------------------------------
kwriteconfig6 --file powermanagementprofilesrc \
  --group AC --group DPMSControl --key idleTime 600

### ------------------------------------------
### Optional: suspend to RAM after 20 minutes
### ------------------------------------------
kwriteconfig6 --file powermanagementprofilesrc \
  --group AC --group SuspendSession --key idleTime 1200

kwriteconfig6 --file powermanagementprofilesrc \
  --group AC --group SuspendSession --key suspendType 1

### ------------------------------------------
### Ensure systemd sleep is allowed
### ------------------------------------------
sudo systemctl unmask sleep.target suspend.target \
  hibernate.target hybrid-sleep.target


### ==================================================
### PipeWire low latency
### ==================================================
mkdir -p ~/.config/pipewire/pipewire.conf.d
cat > ~/.config/pipewire/pipewire.conf.d/low-latency.conf <<EOF
context.properties = {
  default.clock.rate = 48000
  default.clock.min-quantum = 64
  default.clock.max-quantum = 128
}
EOF
### ==================================================
### Breeze Dark + Papirus Dark
### ==================================================
kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
plasma-apply-lookandfeel org.kde.breezedark.desktop || true

### ==================================================
### Autologin tty1
### ==================================================
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF

### ==================================================
### Zsh + Powerlevel10k
### ==================================================
touch ~/.zshrc
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k || true
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc

### Configure Compose Key
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/compose-key.conf <<EOF
XKBOPTIONS=compose:ralt
EOF

wget https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Felis_catus-cat_on_snow.jpg/1280px-Felis_catus-cat_on_snow.jpg
plasma-apply-wallpaperimage 1280px-Felis_catus-cat_on_snow.jpg
echo "=================================================="
echo " SETUP COMPLETE — REBOOTING"
echo "=================================================="

sudo reboot
