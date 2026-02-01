#!/bin/bash


append_once() {
  grep -qxF "$1" "$2" 2>/dev/null || echo "$1" | sudo tee -a "$2" >/dev/null
}

sudo apt update
sudo apt full-upgrade -y

sudo apt install -y --no-install-recommends \
  wget curl git python3 python3-pip python3-venv zsh nodejs npm

sudo apt install -y --no-install-recommends \
  plasma-desktop plasma-workspace kwin-wayland xwayland \
  plasma-nm libklipper6 bluedevil upower udisks2 \
  dolphin konsole kdialog kate vlc

sudo apt purge -y \
  plasma-discover kdeconnect kdeconnectd \
  baloo-kf6 baloo-kf6-modules \
  cups cups-daemon cups-client || true

sudo apt autoremove -y
sudo apt autoclean

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

cat >> ~/.zprofile <<'EOF'

if [[ "$(tty)" == "/dev/tty1" && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
  sleep 2
  exec startplasma-wayland
fi
EOF


systemctl --user disable plasma-powerdevil.service 2>/dev/null || true
systemctl --user disable plasma-baloo.service 2>/dev/null || true

sudo mkdir -p /etc/cloud
sudo touch /etc/cloud/cloud-init.disable

git clone https://github.com/Botspot/pi-apps.git "$HOME/pi-apps"

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

  mkdir -p ~/.config/Code/User
  cat > ~/.config/Code/User/argv.json <<'EOF'
{
  "enable-crash-reporter": false,
  "ozone-platform": "wayland",
  "enable-features": "UseOzonePlatform"
}
EOF

export ZSH="$HOME/.oh-my-zsh"
if [ ! -d "$ZSH" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

if [ "$SHELL" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)"
fi

is_pi5() {
  grep -q "Raspberry Pi 5" /proc/device-tree/model 2>/dev/null
}

if is_pi5; then
  echo "Applying Raspberry Pi 5 auto-tuning"

  # CPU governor: performance
  for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -w "$gov" ] && echo performance | sudo tee "$gov" >/dev/null
  done

  # GPU memory (Wayland + Plasma)
  if [ -f /boot/config.txt ]; then
    sudo sed -i '/^gpu_mem=/d' /boot/config.txt
    echo "gpu_mem=256" | sudo tee -a /boot/config.txt >/dev/null
  fi

  # VM tuning (better Plasma responsiveness)
  sudo tee /etc/sysctl.d/99-pi5.conf >/dev/null <<EOF
vm.swappiness=180
vm.vfs_cache_pressure=50
EOF

  sudo sysctl --system >/dev/null
fi


echo "Done. Reboot recommended."

read -rp "Reboot now? [y/N]: " ans
case "$ans" in
  y|Y|yes|YES)
    sudo reboot
    ;;
  *)
    echo "Reboot skipped. Please reboot manually later."
    ;;
esac


# Please run this on debian or raspberry pi os lite. Maybe ubuntu server and diet pi would work too. 
# Run with ssh or locally after first boot, screen security thingy added so use raspi connect.
# bash <(curl -fsSL https://raw.githubusercontent.com/kotznayet/katos/main/main.sh)
