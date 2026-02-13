#!/bin/bash
set -e

# ==================================================
# Base system update
# ==================================================
sudo apt update
sudo apt full-upgrade -y

# ==================================================
# Core packages + KDE Plasma (Wayland)
# ==================================================
sudo apt install -y --no-install-recommends \
wget curl git python3 python3-pip python3-venv zsh nodejs npm \
plasma-desktop plasma-workspace kwin-wayland xwayland plasma-nm \
bluedevil upower udisks2 dolphin konsole kdialog kate vlc code \
imagemagick kde-spectacle ark filelight systemsettings powerdevil \
plasma-pa plasma-disks plasma-integration plasma-browser-integration \
plasma-sdk kwalletmanager kde-cli-tools partitionmanager rpi-eeprom \
exfatprogs nmap kcalc okular pipewire pipewire-jack wireplumber \
obs-studio command-not-found tmux earlyoom

# ==================================================
# Kill cloud-init completely
# ==================================================
sudo systemctl disable cloud-init.service cloud-init-local.service \
cloud-config.service cloud-final.service 2>/dev/null || true

sudo systemctl mask cloud-init.service cloud-init-local.service \
cloud-config.service cloud-final.service 2>/dev/null || true

sudo apt purge -y cloud-init || true
sudo rm -rf /etc/cloud /var/lib/cloud

# ==================================================
# Kill ALL wait-for-network delays
# ==================================================
sudo systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
sudo systemctl mask NetworkManager-wait-online.service 2>/dev/null || true

sudo systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true

# ==================================================
# Wayland environment (TTY auto-start)
# ==================================================
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/wayland.conf <<EOF
QT_QPA_PLATFORM=wayland
XDG_CURRENT_DESKTOP=KDE
EOF

if ! grep -q startplasma-wayland ~/.zprofile 2>/dev/null; then
cat >> ~/.zprofile <<'EOF'

# Start KDE Wayland on tty1 only (no DM)
if [[ "$(tty)" == "/dev/tty1" && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
  exec startplasma-wayland
fi
EOF
fi

# ==================================================
# Disable useless services
# ==================================================
sudo systemctl disable ModemManager.service smartmontools.service 2>/dev/null || true

# ==================================================
# Pi-Apps (Vivaldi only)
# ==================================================
if [ ! -f "$HOME/pi-apps/manage" ]; then
  git clone https://github.com/Botspot/pi-apps.git "$HOME/pi-apps"
  "$HOME/pi-apps/install"
fi

"$HOME/pi-apps/manage" install Vivaldi || true

mkdir -p ~/.config
echo "--ozone-platform=wayland" > ~/.config/vivaldi-flags.conf
echo "--ozone-platform=wayland" > ~/.config/chromium-flags.conf

# ==================================================
# VS Code Wayland flags (future-proof)
# ==================================================
mkdir -p ~/.config/Code/User
cat > ~/.config/Code/User/argv.json <<EOF
{
  "enable-crash-reporter": false,
  "ozone-platform": "wayland",
  "enable-features": "UseOzonePlatform"
}
EOF

# ==================================================
# Oh My Zsh + Powerlevel10k
# ==================================================
export ZSH="$HOME/.oh-my-zsh"
RUNZSH=no CHSH=yes KEEP_ZSHRC=no \
yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
echo 'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' >> ~/.zshrc

# ==================================================
# CPU governor (performance)
# ==================================================
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance | sudo tee "$gov" >/dev/null || true
done

# ==================================================
# VM tuning
# ==================================================
sudo tee /etc/sysctl.d/99-pi5.conf >/dev/null <<EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
sudo sysctl --system >/dev/null

# ==================================================
# earlyoom (prevents freezes)
# ==================================================
sudo tee /etc/default/earlyoom >/dev/null <<'EOF'
EARLYOOM_ARGS="-r 3600 -m 8 -s 10 --prefer '^(pipewire|wireplumber|kwin|plasmashell)$' --avoid '^(sshd|systemd|dbus|login|Xwayland)$'"
EARLYOOM_VERBOSE=0
EOF

sudo systemctl enable --now earlyoom

# ==================================================
# Low-latency PipeWire
# ==================================================
mkdir -p ~/.config/pipewire

if [ ! -f ~/.config/pipewire/pipewire.conf ]; then
  cp /usr/share/pipewire/pipewire.conf ~/.config/pipewire/
fi

sed -i \
  -e 's/#default.clock.rate.*/default.clock.rate = 48000/' \
  -e 's/#default.clock.quantum.*/default.clock.quantum = 128/' \
  -e 's/#default.clock.min-quantum.*/default.clock.min-quantum = 64/' \
  -e 's/#default.clock.max-quantum.*/default.clock.max-quantum = 256/' \
  ~/.config/pipewire/pipewire.conf

mkdir -p ~/.config/wireplumber/main.lua.d
cat > ~/.config/wireplumber/main.lua.d/90-realtime.lua <<'EOF'
alsa_monitor.rules = {
  {
    matches = {
      { { "node.name", "matches", "alsa_*" }, },
    },
    apply_properties = {
      ["node.latency"] = "128/48000",
      ["priority.driver"] = 200,
      ["priority.session"] = 200,
    },
  },
}
EOF

systemctl --user daemon-reexec
systemctl --user restart pipewire pipewire-pulse wireplumber

# ==================================================
# EEPROM FAST BOOT (FULL CONFIG — NO 30s DELAY)
# ==================================================
TMP_EEPROM=$(mktemp)

cat > "$TMP_EEPROM" <<'EOF'
[all]
BOOT_UART=0
BOOT_ORDER=0xf41
NET_INSTALL_AT_POWER_ON=0
POWER_OFF_ON_HALT=0
WAKE_ON_GPIO=0
HDMI_DELAY=0
DISABLE_HDMI=0
EOF

sudo rpi-eeprom-config --apply "$TMP_EEPROM"
rm -f "$TMP_EEPROM"

# ==================================================
# Overclock (Pi 5 SAFE)
# ==================================================
sudo sed -i '/arm_freq=/d;/gpu_freq=/d;/over_voltage_delta=/d;/force_turbo=/d' \
/boot/firmware/config.txt

sudo tee -a /boot/firmware/config.txt >/dev/null <<EOF
arm_freq=2600
gpu_freq=900
over_voltage_delta=50000
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
# Tiny swapfile (512MB)
# ==================================================
sudo swapoff -a
sudo sed -i '/\sswap\s/d' /etc/fstab

SWAPFILE=/swapfile
if [ ! -f "$SWAPFILE" ]; then
  sudo fallocate -l 512M "$SWAPFILE" || sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=512
  sudo chmod 600 "$SWAPFILE"
  sudo mkswap "$SWAPFILE"
fi

sudo swapon -p -100 "$SWAPFILE"
echo "$SWAPFILE none swap sw,pri=-100 0 0" | sudo tee -a /etc/fstab >/dev/null

# ==================================================
# Autologin tty1
# ==================================================
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF

# ==================================================
# Final
# ==================================================
echo "✅ Setup complete. Firmware delay FIXED."
echo "🔁 Reboot strongly recommended."

read -rp "Reboot now? [y/N]: " ans
[[ "$ans" =~ ^[Yy] ]] && sudo reboot
