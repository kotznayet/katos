#!/bin/bash
set -e

### ==================================================
### Base system
### ==================================================
sudo apt update
sudo apt full-upgrade -y

sudo apt install -y --no-install-recommends \
  wget curl git zsh tmux unzip \
  python3 python3-pip python3-venv \
  nodejs npm \
  plasma-desktop plasma-workspace kwin-wayland xwayland \
  plasma-nm bluedevil dolphin konsole kate kdialog \
  vlc kde-spectacle ark filelight systemsettings powerdevil \
  plasma-pa plasma-disks plasma-integration plasma-browser-integration \
  plasma-sdk kwalletmanager kde-cli-tools partitionmanager \
  pipewire pipewire-jack wireplumber \
  obs-studio earlyoom code \
  rpi-eeprom exfatprogs nmap kcalc \
  command-not-found

### ==================================================
### Kill cloud-init
### ==================================================
sudo systemctl disable --now cloud-init.service cloud-init-local.service \
  cloud-config.service cloud-final.service 2>/dev/null || true
sudo systemctl mask cloud-init.service cloud-init-local.service \
  cloud-config.service cloud-final.service 2>/dev/null || true
sudo apt purge -y cloud-init || true
sudo rm -rf /etc/cloud /var/lib/cloud
sudo touch /etc/cloud/cloud-init.disable

### ==================================================
### Kill wait-online delays
### ==================================================
sudo systemctl disable --now NetworkManager-wait-online.service \
  systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl mask NetworkManager-wait-online.service \
  systemd-networkd-wait-online.service 2>/dev/null || true

### ==================================================
### Wayland environment
### ==================================================
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/wayland.conf <<EOF
QT_QPA_PLATFORM=wayland
XDG_CURRENT_DESKTOP=KDE
EOF

### ==================================================
### Auto-start Plasma Wayland ONLY on tty1
### ==================================================
if ! grep -q startplasma-wayland ~/.zprofile 2>/dev/null; then
cat >> ~/.zprofile <<'EOF'

if [[ "$(tty)" == "/dev/tty1" && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
  exec startplasma-wayland
fi
EOF
fi

### ==================================================
### Konsole: correct shell handling (Plasma 6)
### ==================================================
mkdir -p ~/.local/share/konsole
cp -n /usr/share/konsole/Main.profile ~/.local/share/konsole/Main.profile

kwriteconfig6 --file ~/.local/share/konsole/Main.profile \
  --group General --key Command "/usr/bin/zsh"

kwriteconfig6 --file konsolerc \
  --group "Desktop Entry" --key DefaultProfile Main.profile

### ==================================================
### Oh My Zsh (no chsh)
### ==================================================
export ZSH="$HOME/.oh-my-zsh"
RUNZSH=no CHSH=no KEEP_ZSHRC=no \
yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

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
### VS Code extensions (Natizyskunk SFTP)
### ==================================================
code --install-extension ms-python.python --force
code --install-extension natizyskunk.sftp --force
code --install-extension esbenp.prettier-vscode --force
code --install-extension PKief.material-icon-theme --force
code --install-extension zhuangtongfa.Material-theme --force

### ==================================================
### VS Code settings + Electron Wayland fixes
### ==================================================
mkdir -p ~/.config/Code/User
cat > ~/.config/Code/User/settings.json <<EOF
{
  "workbench.colorTheme": "One Dark Pro",
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
  "disable-gpu-sandbox": true,
  "disable-hardware-acceleration": false
}
EOF

### ==================================================
### Global Electron flags (Chromium / Vivaldi / Code)
### ==================================================
cat > ~/.config/electron-flags.conf <<EOF
--ozone-platform=wayland
--enable-features=UseOzonePlatform
--disable-gpu-sandbox
--disable-features=WaylandWindowDecorations
--use-gl=egl
EOF

### ==================================================
### earlyoom (responsive OOM killer)
### ==================================================
sudo systemctl enable --now earlyoom
sudo sed -i \
  's/^EARLYOOM_ARGS=.*/EARLYOOM_ARGS="-r 60 -m 5 -s 10 --avoid '\''^(plasmashell|kwin_wayland)$'\''"/' \
  /etc/default/earlyoom || true
sudo systemctl restart earlyoom

### ==================================================
### PipeWire low latency
### ==================================================
mkdir -p ~/.config/pipewire/pipewire.conf.d
cat > ~/.config/pipewire/pipewire.conf.d/low-latency.conf <<EOF
context.properties = {
  default.clock.rate = 48000
  default.clock.quantum = 64
  default.clock.min-quantum = 32
  default.clock.max-quantum = 128
}
EOF

### ==================================================
### EEPROM fix (no 30s firmware delay)
### ==================================================
TMP_EEPROM=$(mktemp)
sudo rpi-eeprom-config > "$TMP_EEPROM"

sed -i \
  -e 's/^BOOT_ORDER=.*/BOOT_ORDER=0xf14/' \
  -e 's/^#\?HDMI_DELAY=.*/HDMI_DELAY=2/' \
  -e 's/^#\?BOOT_UART=.*/BOOT_UART=0/' \
  -e 's/^#\?NET_INSTALL_AT_POWER_ON=.*/NET_INSTALL_AT_POWER_ON=0/' \
  "$TMP_EEPROM"

sudo rpi-eeprom-config --apply "$TMP_EEPROM"
rm -f "$TMP_EEPROM"

### ==================================================
### Overclock (Pi 5 + active cooler, safe)
### ==================================================
sudo sed -i '/arm_freq=/d;/gpu_freq=/d;/over_voltage_delta=/d' /boot/firmware/config.txt
sudo tee -a /boot/firmware/config.txt >/dev/null <<EOF
arm_freq=2800
gpu_freq=900
over_voltage_delta=80000
EOF

### ==================================================
### Active cooler control
### ==================================================
sudo sed -i '/fan_temp/d;/fan_pwm/d' /boot/firmware/config.txt
sudo tee -a /boot/firmware/config.txt >/dev/null <<EOF
dtparam=fan_temp0=50000
dtparam=fan_temp1=60000
dtparam=fan_temp2=70000
dtparam=fan_pwm=1
EOF

### ==================================================
### Tela icons + Breeze Dark
### ==================================================
if [ ! -d /usr/share/icons/Tela ]; then
  TMP_TELA=$(mktemp -d)
  git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git "$TMP_TELA"
  sudo "$TMP_TELA/install.sh" -a
  rm -rf "$TMP_TELA"
fi

plasma-apply-lookandfeel org.kde.breezedark.desktop || true
kwriteconfig6 --file kdeglobals --group Icons --key Theme Tela

### ==================================================
### VLC native Wayland dark
### ==================================================
mkdir -p ~/.config/vlc
cat > ~/.config/vlc/vlcrc <<EOF
qt-application-theme=dark
qt-system-tray=false
qt-minimal-view=true
EOF

### ==================================================
### Swap (small, deterministic)
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

echo "=================================================="
echo " SETUP COMPLETE — REBOOT STRONGLY RECOMMENDED"
echo "=================================================="

read -rp "Reboot now? [y/N]: " ans
[[ "$ans" =~ ^[Yy] ]] && sudo reboot
