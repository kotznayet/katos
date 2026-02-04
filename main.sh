#!/bin/bash
set -e

sudo apt update
sudo apt full-upgrade -y

sudo apt install -y --no-install-recommends \
wget curl git python3 python3-pip python3-venv zsh nodejs npm \
plasma-desktop plasma-workspace kwin-wayland xwayland plasma-nm \
bluedevil upower udisks2 dolphin konsole kdialog kate vlc code \
imagemagick kde-spectacle ark filelight systemsettings powerdevil \
plasma-pa plasma-disks plasma-integration plasma-browser-integration \
plasma-sdk kwalletmanager kde-cli-tools partitionmanager rpi-eeprom \
exfatprogs nmap kcalc okular pipewire-jack wireplumber obs-studio \
command-not-found tmux

# ==================================================
# Kill cloud-init completely (Pi Imager already ran)
# ==================================================

sudo systemctl disable cloud-init.service \
  cloud-init-local.service \
  cloud-config.service \
  cloud-final.service 2>/dev/null || true

sudo systemctl mask cloud-init.service \
  cloud-init-local.service \
  cloud-config.service \
  cloud-final.service 2>/dev/null || true

sudo apt purge -y cloud-init || true
sudo rm -rf /etc/cloud /var/lib/cloud

# ==================================================
# Kill ALL wait-for-network boot delays
# ==================================================

sudo systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
sudo systemctl mask NetworkManager-wait-online.service 2>/dev/null || true

sudo systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true


# ==================================================
# Wayland environment
# ==================================================
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/wayland.conf <<EOF
QT_QPA_PLATFORM=wayland
XDG_CURRENT_DESKTOP=KDE
EOF

if ! grep -q startplasma-wayland ~/.zprofile 2>/dev/null; then
cat >> ~/.zprofile <<'EOF'

if [[ "$(tty)" == "/dev/tty1" && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
  exec startplasma-wayland
fi
EOF
fi

# ==================================================
# Disable useless services
# ==================================================
sudo systemctl disable ModemManager.service smartmontools.service
sudo touch /etc/cloud/cloud-init.disable

# ==================================================
# pi-apps (for Vivaldi only)
# ==================================================
if [ ! -f "$HOME/pi-apps/manage" ]; then
  git clone https://github.com/Botspot/pi-apps.git "$HOME/pi-apps"
  "$HOME/pi-apps/install"
fi

"$HOME/pi-apps/manage" install Vivaldi || true

mkdir -p ~/.config
echo "--ozone-platform=wayland" > ~/.config/vivaldi-flags.conf
echo "--ozone-platform=wayland" > ~/.config/chromium-flags.conf

mkdir -p ~/.config/Code/User
cat > ~/.config/Code/User/argv.json <<EOF
{
  "enable-crash-reporter": false,
  "ozone-platform": "wayland",
  "enable-features": "UseOzonePlatform"
}
EOF

# ==================================================
# Oh My Zsh
# ==================================================
export ZSH="$HOME/.oh-my-zsh"
RUNZSH=no CHSH=yes KEEP_ZSHRC=no \
yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# ==================================================
# CPU governor
# ==================================================
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance | sudo tee "$gov" >/dev/null || true
done

# ==================================================
# VM tuning (swapfile-correct)
# ==================================================
sudo tee /etc/sysctl.d/99-pi5.conf >/dev/null <<EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
sudo sysctl --system >/dev/null

# ==================================================
# EEPROM fast boot (HDMI enabled)
# ==================================================
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
# Overclock (Pi 5 + Active Cooler)
# ==================================================
sudo sed -i '/arm_freq=/d;/gpu_freq=/d;/over_voltage_delta=/d;/force_turbo=/d' \
/boot/firmware/config.txt

sudo tee -a /boot/firmware/config.txt >/dev/null <<EOF
arm_freq=2800
gpu_freq=1000
over_voltage_delta=80000
force_turbo=0
EOF

# ==================================================
# Active Cooler
# ==================================================
sudo systemctl mask rpi-poe-fan.service 2>/dev/null || true

sudo sed -i '/gpio-fan/d;/fan_temp/d;/fan_pwm/d' /boot/firmware/config.txt

sudo tee -a /boot/firmware/config.txt >/dev/null <<EOF
dtparam=fan_temp0=50000
dtparam=fan_temp1=55000
dtparam=fan_temp2=60000
dtparam=fan_temp3=65000
dtparam=fan_pwm=1
EOF

# ==================================================
# Plasma 6 theme + icons
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

mkdir -p ~/.config/vlc
cat > ~/.config/vlc/vlcrc <<EOF
qt-application-theme=dark
qt-system-tray=false
qt-minimal-view=true
EOF

# ==================================================
# Wayland sleep ON, DPMS OFF, NO LOCKSCREEN
# ==================================================
kwriteconfig6 --file kwinrc --group DPMS --key Enabled false
kwriteconfig6 --file kwinrc --group DPMS --key Timeout 0

kwriteconfig6 --file powerdevilrc --group General --key LockOnSuspend false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Timeout 0
kwriteconfig6 --file kded5rc --group Module-kscreenlocker --key autoload false

systemctl --user mask plasma-kscreenlocker.service kscreenlocker.service 2>/dev/null || true

# ==================================================
# Console never blank
# ==================================================
sudo sed -i 's/consoleblank=[0-9]\+/consoleblank=0/' /boot/firmware/cmdline.txt || \
sudo sed -i 's/$/ consoleblank=0/' /boot/firmware/cmdline.txt
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

echo 'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' >> ~/.zshrc

# ==================================================
# Tiny swapfile (NO ZRAM)
# ==================================================
sudo swapoff -a
sudo sed -i '/\sswap\s/d' /etc/fstab

SWAPFILE=/swapfile
if [ ! -f "$SWAPFILE" ]; then
  sudo fallocate -l 512M "$SWAPFILE" || sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=512
  sudo chmod 600 "$SWAPFILE"
  sudo mkswap "$SWAPFILE"
fi

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d

sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF


sudo swapon -p -100 "$SWAPFILE"
echo "$SWAPFILE none swap sw,pri=-100 0 0" | sudo tee -a /etc/fstab >/dev/null

echo "Setup complete. Reboot strongly recommended."

read -rp "Reboot now? [y/N]: " ans
[[ "$ans" =~ ^[Yy] ]] && sudo reboot

# Please run this on raspberry pi os lite. Maybe diet pi would work too.
# Run with ssh or locally after first boot.
# bash <(curl -fsSL https://raw.githubusercontent.com/kotznayet/katos/main/main.sh)
