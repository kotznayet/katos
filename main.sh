#!/bin/bash
set -e

### ==================================================
### Base system
### ==================================================
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y --no-install-recommends sudo \
  wget curl git zsh unzip \
  python3 python3-pip python3-venv \
  nodejs npm firefox-esr \
  labwc qlipper vlc dolphin kate kdialog \
  vlc ark filelight powerdevil plasma-pa \
  pipewire pipewire-jack wireplumber earlyoom \
  rpi-eeprom exfatprogs nmap kcalc code \
  command-not-found screen
  
### ==================================================
### Tela icon theme (install minimal)
### ==================================================
TMP_TELA=$(mktemp -d)

git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme "$TMP_TELA"

cd "$TMP_TELA"

# Install ONLY the standard dark variant (avoids installing all variants)
./install.sh -d ~/.icons -n Tela

cd
rm -rf "$TMP_TELA"
### ==================================================
### Kill cloud-init
### ==================================================
sudo systemctl disable --now cloud-init.service cloud-init-local.service \
  cloud-config.service cloud-final.service 2>/dev/null || true
sudo systemctl mask cloud-init.service cloud-init-local.service \
  cloud-config.service cloud-final.service 2>/dev/null || true
sudo apt purge -y cloud-init kscreenlocker || true
sudo rm -rf /etc/cloud /var/lib/cloud

### ==================================================
### Kill wait-online delays
### ==================================================
sudo systemctl disable --now NetworkManager-wait-online.service \
  systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl mask NetworkManager-wait-online.service \
  systemd-networkd-wait-online.service 2>/dev/null || true

### ==================================================
### Wayland environment (still optional)
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
  mkdir -p ~/.config/pi-apps
  cat > ~/.config/pi-apps/settings.conf <<EOF
DESKTOP_SHORTCUTS=false
EOF
  "$HOME/pi-apps/install"
fi
"$HOME/pi-apps/manage" install "OBS Studio"

### ==================================================
### tty1 → labwc autostart
### ==================================================
grep -q startx ~/.profile 2>/dev/null || cat >> ~/.profile <<'EOF'
if [[ "$(tty)" == "/dev/tty1" && -z "$DISPLAY" ]]; then
  exec startx
fi
EOF

### ==================================================
### Konsole → zsh (no chsh)
### ==================================================
mkdir -p ~/.local/share/konsole
cat > ~/.local/share/konsole/zsh.profile <<EOF
[General]
Name=zsh
Command=/usr/bin/zsh
EOF

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
### Firefox ESR policies + extensions
### ==================================================
sudo mkdir -p /etc/firefox/policies
sudo tee /etc/firefox/policies/policies.json >/dev/null <<'EOF'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableFeedbackCommands": true,
    "ExtensionSettings": {
      "*": { "installation_mode": "allowed" },
      "uBlock0@raymondhill.net": {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
        "installation_mode": "force_installed"
      },
      "sponsorBlocker@ajay.app": {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi",
        "installation_mode": "force_installed"
      },
      "jid1-BoFifL9Vbdl2zQ@jetpack": {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/youtube-shorts-block/latest.xpi",
        "installation_mode": "force_installed"
      }
    }
  }
}
EOF

### ==================================================
### VS Code extensions
### ==================================================
code --version >/dev/null 2>&1 || true
sleep 2
code --install-extension ms-python.python --force
code --install-extension natizyskunk.sftp --force
code --install-extension esbenp.prettier-vscode --force
code --install-extension PKief.material-icon-theme --force

### ==================================================
### VS Code settings + Electron Wayland
### ==================================================
mkdir -p ~/.config/Code/User
cat > ~/.config/Code/User/settings.json <<EOF
{
  "workbench.iconTheme": "material-icon-theme",
  "editor.fontFamily": "CascadiaCode Nerd Font, monospace",
  "editor.fontLigatures": true,
  "terminal.integrated.fontFamily": "CascadiaCode Nerd Font",
  "window.titleBarStyle": "custom",
  "window.menuBarVisibility": "compact"
}
EOF
cat > ~/.config/Code/User/argv.json <<EOF
{
  "ozone-platform": "wayland",
  "enable-features": "UseOzonePlatform",
  "disable-gpu-sandbox": true
}
EOF

### ==================================================
### earlyoom
### ==================================================
sudo tee /etc/default/earlyoom >/dev/null <<EOF
EARLYOOM_ARGS="-r 60 -m 5 -s 10 --prefer '^(yes|firefox|code|konsole)$'"
EOF
sudo systemctl enable --now earlyoom

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
### Pi 5 overclock + fan
### ==================================================
sudo sed -i '/arm_freq=/d;/gpu_freq=/d;/over_voltage_delta=/d' /boot/firmware/config.txt
sudo tee -a /boot/firmware/config.txt >/dev/null <<EOF
arm_freq=2800
gpu_freq=900
over_voltage_delta=80000
dtparam=fan_temp0=50000
dtparam=fan_temp1=60000
dtparam=fan_temp2=70000
EOF

### ==================================================
### Labwc theme: Breeze dark
### ==================================================
mkdir -p ~/.config/labwc/themes
cat > ~/.config/labwc/themes/breeze.lua <<'EOF'
theme.background = "#2e3440"
theme.focus = "#5294e2"
theme.text_normal = "#d8dee9"
theme.text_focus = "#ffffff"
theme.border_width = 2
theme.border_color = "#5294e2"
theme.font = "CascadiaCode Nerd Font 10"
EOF

### ==================================================
### Swap
### ==================================================
sudo swapoff -a
sudo sed -i '/\sswap\s/d' /etc/fstab
if [ ! -f /swapfile ]; then
  sudo fallocate -l 512M /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=512
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
fi
sudo swapon -p -100 /swapfile
echo "/swapfile none swap sw,pri=-100 0 0" | sudo tee -a /etc/fstab >/dev/null

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
echo 'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' >> ~/.zshrc
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k || true
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc

echo "=================================================="
echo " SETUP COMPLETE — REBOOTING"
echo "=================================================="

sudo reboot
