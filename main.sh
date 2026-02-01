#!/bin/bash
set -eo pipefail

# enter screen once
sudo apt install screen
if [ -z "${STY:-}" ] && ! screen -list | grep -q plasma-dev; then
  exec screen -S plasma-dev bash "$0"
fi

have() { command -v "$1" >/dev/null 2>&1; }

append_once() {
  grep -qxF "$1" "$2" 2>/dev/null || echo "$1" | sudo tee -a "$2" >/dev/null
}

sudo apt update
sudo apt full-upgrade -y

sudo apt install -y --no-install-recommends \
  wget curl git ca-certificates gnupg \
  build-essential ripgrep fd-find \
  python3 python3-pip python3-venv \
  screen zsh nodejs npm

sudo apt install -y --no-install-recommends \
  plasma-desktop plasma-workspace kwin-wayland xwayland \
  plasma-nm klipper bluedevil upower udisks2 \
  dolphin konsole kdialog kate vlc

sudo apt purge -y \
  plasma-discover kdeconnect kdeconnectd \
  baloo-kf6 baloo-kf6-modules \
  cups cups-daemon cups-client || true

sudo apt autoremove -y
sudo apt autoclean

have balooctl6 && balooctl6 disable || true

if [ -f /boot/config.txt ]; then
  sudo sed -i \
    -e 's/^dtoverlay=vc4-fkms-v3d/#&/' \
    -e '/^dtoverlay=vc4-kms-v3d/d' \
    /boot/config.txt
  append_once "dtoverlay=vc4-kms-v3d" /boot/config.txt
  append_once "gpu_mem=128" /boot/config.txt
fi

mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/wayland.conf <<EOF
QT_QPA_PLATFORM=wayland
XDG_CURRENT_DESKTOP=KDE
EOF

if ! grep -q startplasma-wayland ~/.zprofile 2>/dev/null; then
cat >> ~/.zprofile <<'EOF'

if [[ "$(tty)" == "/dev/tty1" && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
  sleep 2
  exec startplasma-wayland
fi
EOF
fi

systemctl --user disable plasma-powerdevil.service 2>/dev/null || true
systemctl --user disable plasma-baloo.service 2>/dev/null || true

sudo mkdir -p /etc/cloud
sudo touch /etc/cloud/cloud-init.disable

if [ ! -d "$HOME/pi-apps" ]; then
  git clone https://github.com/Botspot/pi-apps.git "$HOME/pi-apps"
fi

set +e
"$HOME/pi-apps/pi-apps" install zram
"$HOME/pi-apps/pi-apps" install vivaldi
set -e

mkdir -p ~/.config/vivaldi/Default
cat > ~/.config/vivaldi/Default/Preferences <<'EOF'
{
  "vivaldi": {
    "desktop": {
      "use_native_window_decoration": true
    }
  }
}
EOF

mkdir -p ~/.config
echo "--ozone-platform=wayland" > ~/.config/vivaldi-flags.conf
echo "--ozone-platform=wayland" > ~/.config/chromium-flags.conf

if have code; then
  mkdir -p ~/.config/Code/User
  cat > ~/.config/Code/User/argv.json <<'EOF'
{
  "enable-crash-reporter": false,
  "ozone-platform": "wayland",
  "enable-features": "UseOzonePlatform"
}
EOF
fi

export ZSH="$HOME/.oh-my-zsh"
if [ ! -d "$ZSH" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

if [ "$SHELL" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)"
fi

echo "Done. Reboot recommended."

# Please run this on debian or raspberry pi os lite. Maybe ubuntu server and diet pi would work too. Run with ssh or locally after first boot, please don't run with raspi connect.
