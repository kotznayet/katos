#!/bin/bash

# Check for internet connectivity
if ! ping -c 1 google.com &>/dev/null; then
  echo "No internet connection. Please check your network and try again."
  exit 1
fi

# Error handling for critical commands
sudo apt update || { echo "Failed to update package list. Exiting..."; exit 1; }
sudo apt full-upgrade -y || { echo "Failed to upgrade packages. Exiting..."; exit 1; }

sudo apt install -y --no-install-recommends \
wget curl git python3 python3-pip python3-venv zsh nodejs npm

sudo apt install -y --no-install-recommends \
 plasma-desktop plasma-workspace kwin-wayland xwayland plasma-nm libklipper6 \
 bluedevil upower udisks2 dolphin konsole kdialog kate vlc code imagemagick \
 kde-spectacle ark filelight systemsettings powerdevil plasma-pa plasma-disks \
 plasma-integration plasma-browser-integration plasma-sdkg \
 kwalletmanager kscreen kde-cli-tools partitionmanager

sudo apt purge -y kdeconnect kdeconnectd cups cups-daemon cups-client || true

sudo apt autoremove -y
sudo apt autoclean -y

echo "gpu_mem=256" | sudo tee -a /boot/firmware/config.txt >/dev/null

mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/wayland.conf <<EOF
QT_QPA_PLATFORM=wayland
XDG_CURRENT_DESKTOP=KDE
EOF

if ! grep -q "exec startplasma-wayland" ~/.zprofile; then
  cat >> ~/.zprofile <<'EOF'

if [[ "$(tty)" == "/dev/tty1" && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
  sleep 2
  exec startplasma-wayland
fi
EOF
fi

systemctl --user disable plasma-powerdevil.service 2>/dev/null || true
systemctl --user disable plasma-baloo.service 2>/dev/null || true
sudo touch /etc/cloud/cloud-init.disable

# Ensure pi-apps is installed before using it
if [ ! -f "$HOME/pi-apps/manage" ]; then
  echo "pi-apps is not installed. Installing..."
  git clone https://github.com/Botspot/pi-apps.git "$HOME/pi-apps"
  "$HOME/pi-apps/install"
fi

if ! "$HOME/pi-apps/manage" install zram; then
  echo "Failed to install zram. Skipping..."
fi

if ! "$HOME/pi-apps/manage" install vivaldi; then
  echo "Failed to install vivaldi. Skipping..."
fi

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

RUNZSH=no CHSH=yes KEEP_ZSHRC=no \
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"



echo "Applying Raspberry Pi 5 auto-tuning"

# CPU governor: performance
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  [ -w "$gov" ] && echo performance | sudo tee "$gov" >/dev/null
done


# VM tuning (better Plasma responsiveness)
sudo tee /etc/sysctl.d/99-pi5.conf >/dev/null <<EOF
vm.swappiness=180
vm.vfs_cache_pressure=50
EOF

sudo sysctl --system >/dev/null

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

# Add custom aliases to .zshrc
cat >> ~/.zshrc <<'EOF'
# Custom Aliases
alias la='ls -la'
alias rf='rm -rf'
alias updgrade='sudo apt update && sudo apt full-upgrade -y'
alias cls='clear'
alias pinstall='./pi-apps/manage install'
EOF

# Install Tela icons and Breeze Dark GTK theme
echo "Installing Tela icons and Breeze Dark GTK theme..."
sudo apt install -y --no-install-recommends tela-icon-theme breeze-gtk-theme

# Set Tela icons and Breeze Dark GTK theme as default
mkdir -p ~/.config/gtk-3.0
cat > ~/.config/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-icon-theme-name=Tela
gtk-theme-name=Breeze-Dark
gtk-font-name=Noto Sans 10
EOF

lookandfeeltool -a org.kde.breezedark.desktop
lookandfeeltool -a org.kde.Tela

# Please run this on raspberry pi os lite. Maybe diet pi would work too.
# Run with ssh or locally after first boot.
# bash <(curl -fsSL https://raw.githubusercontent.com/kotznayet/katos/main/main.sh)
