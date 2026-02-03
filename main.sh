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
 plasma-integration plasma-browser-integration plasma-sdk \
 kwalletmanager kscreen kde-cli-tools partitionmanager

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

sudo systemctl disable ModemManager.service
sudo systemctl disable smartmontools.service
sudo touch /etc/cloud/cloud-init.disable

# Ensure pi-apps is installed before using it
if [ ! -f "$HOME/pi-apps/manage" ]; then
  echo "pi-apps is not installed. Installing..."
  git clone https://github.com/Botspot/pi-apps.git "$HOME/pi-apps"
  "$HOME/pi-apps/install"
fi

if ! "$HOME/pi-apps/manage" install "More RAM"; then
  echo "Failed to install zram. Skipping..."
fi

if ! "$HOME/pi-apps/manage" install Vivaldi; then
  echo "Failed to install vivaldi. Skipping..."
fi

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

# Add custom aliases to .zshrc
cat >> ~/.zshrc <<'EOF'
# Custom Aliases
alias la='ls -la'
alias rf='rm -rf'
alias updgrade='sudo apt update && sudo apt full-upgrade -y'
alias cls='clear'
alias pinstall='./pi-apps/manage install'
EOF

echo "Applying Pi 5 performance + Plasma 6 setup (FINAL)"

# ==================================================
# EEPROM: fast boot (SAFE, HDMI ENABLED)
# ==================================================
sudo apt install -y rpi-eeprom

TMP_EEPROM=$(mktemp)
sudo rpi-eeprom-config > "$TMP_EEPROM"

sed -i \
  -e 's/^BOOT_ORDER=.*/BOOT_ORDER=0xf14/' \
  -e 's/^#\?HDMI_DELAY=.*/HDMI_DELAY=0/' \
  -e 's/^#\?DISABLE_HDMI=.*/DISABLE_HDMI=0/' \
  -e 's/^#\?BOOT_UART=.*/BOOT_UART=0/' \
  -e 's/^#\?NET_INSTALL_AT_POWER_ON=.*/NET_INSTALL_AT_POWER_ON=0/' \
  -e 's/^#\?WAKE_ON_GPIO=.*/WAKE_ON_GPIO=0/' \
  -e 's/^#\?POWER_OFF_ON_HALT=.*/POWER_OFF_ON_HALT=0/' \
  "$TMP_EEPROM"

sudo rpi-eeprom-config --apply "$TMP_EEPROM"
rm -f "$TMP_EEPROM"

# ==================================================
# OVERCLOCK: High but sane (Pi 5 + Active Cooler)
# ==================================================
sudo sed -i '/^arm_freq=/d;/^gpu_freq=/d;/^over_voltage_delta=/d;/^force_turbo=/d' /boot/firmware/config.txt

sudo tee -a /boot/firmware/config.txt >/dev/null <<EOF
# High performance overclock (Pi 5)
arm_freq=2800
gpu_freq=1000
over_voltage_delta=80000
force_turbo=0
EOF

# ==================================================
# Active Cooler: firmware fan (no delay)
# ==================================================
sudo systemctl disable rpi-poe-fan.service 2>/dev/null || true
sudo systemctl mask rpi-poe-fan.service 2>/dev/null || true

sudo sed -i '/gpio-fan/d;/^dtparam=fan_/d;/^fan_temp/d' /boot/firmware/config.txt

sudo tee -a /boot/firmware/config.txt >/dev/null <<EOF
# Official Pi 5 Active Cooler
dtparam=fan_temp0=50000
dtparam=fan_temp1=55000
dtparam=fan_temp2=60000
dtparam=fan_temp3=65000
dtparam=fan_pwm=1
EOF

# ==================================================
# Plasma 6: Breeze Dark + Tela icons
# ==================================================
if [ ! -d /usr/share/icons/Tela ]; then
  TMP_TELA=$(mktemp -d)
  git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git "$TMP_TELA"
  sudo "$TMP_TELA/install.sh" -a
  rm -rf "$TMP_TELA"
fi

plasma-apply-lookandfeel org.kde.breezedark.desktop || true

kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
kwriteconfig6 --file kdeglobals --group Icons --key Theme Tela
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze

kwriteconfig6 --file gtkrc --group Settings --key gtk-theme-name Breeze-Dark
kwriteconfig6 --file gtkrc --group Settings --key gtk-icon-theme-name Tela

# ==================================================
# Plasma 6: Wayland sleep ON, DPMS OFF, NO LOCKER
# ==================================================
kwriteconfig6 --file kwinrc --group DPMS --key Enabled false
kwriteconfig6 --file kwinrc --group DPMS --key Timeout 0

kwriteconfig6 --file powermanagementprofilesrc --group AC --key suspendOnIdle true
kwriteconfig6 --file powermanagementprofilesrc --group AC --key idleTime 900
kwriteconfig6 --file powermanagementprofilesrc --group AC --key turnOffDisplayWhenIdle false

kwriteconfig6 --file powerdevilrc --group General --key LockOnSuspend false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Timeout 0

systemctl --user mask plasma-kscreenlocker.service 2>/dev/null || true
systemctl --user mask kscreenlocker.service 2>/dev/null || true

# ==================================================
# Kernel console: never blank (DSI safety)
# ==================================================
sudo sed -i 's/consoleblank=[0-9]\+/consoleblank=0/' /boot/firmware/cmdline.txt || \
sudo sed -i 's/$/ consoleblank=0/' /boot/firmware/cmdline.txt

echo "Configuring tiny swap file safety net (no zram)"

# ===============================================
# REMOVE ALL ZRAM / OLD SWAP FIRST
# ===============================================
sudo swapoff -a

sudo systemctl disable zram-config.service zram-swap.service 2>/dev/null || true
sudo systemctl mask zram-config.service zram-swap.service 2>/dev/null || true
sudo systemctl mask dev-zram0.swap dev-zram0.device 2>/dev/null || true

sudo apt purge -y systemd-zram-generator 2>/dev/null || true

sudo rm -f /etc/systemd/zram-generator.conf
sudo rm -f /etc/default/zram-config
sudo rm -f /etc/systemd/system/zram-*.service

sudo sed -i '/\sswap\s/d' /etc/fstab

# ===============================================
# CREATE TINY SWAP FILE (512 MB, LOW PRIORITY)
# ===============================================
SWAPFILE=/swapfile

if [ ! -f "$SWAPFILE" ]; then
  sudo fallocate -l 512M "$SWAPFILE" || sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=512
  sudo chmod 600 "$SWAPFILE"
  sudo mkswap "$SWAPFILE"
fi

# Enable immediately
sudo swapon -p -100 "$SWAPFILE"

# Enable permanently
echo "$SWAPFILE none swap sw,pri=-100 0 0" | sudo tee -a /etc/fstab >/dev/null

echo "Tiny swap file enabled (512MB, low priority)"


echo "FINAL setup applied. Reboot required."

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

# Please run this on raspberry pi os lite. Maybe diet pi would work too.
# Run with ssh or locally after first boot.
# bash <(curl -fsSL https://raw.githubusercontent.com/kotznayet/katos/main/main.sh)
