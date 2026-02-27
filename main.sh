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
  nodejs npm papirus-icon-theme firefox-esr \
  plasma-desktop plasma-workspace kwin-x11 xserver-xorg xinit \
  plasma-nm bluedevil dolphin konsole kate kdialog \
  vlc kde-spectacle ark filelight systemsettings powerdevil \
  plasma-pa kscreen plasma-integration plasma-browser-integration \
  kwalletmanager kde-cli-tools partitionmanager \
  pipewire pipewire-jack wireplumber earlyoom \
  rpi-eeprom exfatprogs nmap kcalc code \
  command-not-found \
  xinput xinput-calibrator xserver-xorg-input-libinput

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
### X11 environment
### ==================================================
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/x11.conf <<EOF
QT_QPA_PLATFORM=xcb
XDG_SESSION_TYPE=x11
XDG_CURRENT_DESKTOP=KDE
MOZ_ENABLE_WAYLAND=0
EOF

### ==================================================
### Touchscreen (X11 + libinput base config)
### ==================================================
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/99-touchscreen.conf >/dev/null <<EOF
Section "InputClass"
    Identifier "Touchscreen"
    MatchIsTouchscreen "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    Option "TransformationMatrix" "1 0 0 0 1 0 0 0 1"
EndSection
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
### tty1 → Plasma X11 (idempotent)
### ==================================================
grep -q startplasma-x11 ~/.profile 2>/dev/null || cat >> ~/.profile <<'EOF'

if [[ "$(tty)" == "/dev/tty1" && -z "$DISPLAY" ]]; then
  exec startplasma-x11
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
### Firefox ESR policies
### ==================================================
sudo mkdir -p /etc/firefox/policies
sudo tee /etc/firefox/policies/policies.json >/dev/null <<EOF
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableFeedbackCommands": true,

    "FirefoxHome": {
      "Search": false,
      "TopSites": false,
      "SponsoredTopSites": false,
      "Highlights": false,
      "Pocket": false,
      "SponsoredPocket": false
    },

    "UserMessaging": {
      "WhatsNew": false,
      "ExtensionRecommendations": false,
      "FeatureRecommendations": false
    },

    "Preferences": {
      "browser.tabs.drawInTitlebar": false,
      "browser.uidensity": 1,
      "browser.compactmode.show": true,
      "widget.use-xdg-desktop-portal.file-picker": 1
    },

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
      },
      "darkreader@darkreader.org": {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi",
        "installation_mode": "force_installed"
      }
    }
  }
}
EOF

### ==================================================
### earlyoom (tuned)
### ==================================================
sudo tee /etc/default/earlyoom >/dev/null <<EOF
EARLYOOM_ARGS="-r 60 -m 5 -s 10 --prefer '^(yes|firefox|code|konsole)$'"
EOF
sudo systemctl enable --now earlyoom

### ==================================================
### Breeze Dark + Papirus Dark
### ==================================================
kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark
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

echo "=================================================="
echo " SETUP COMPLETE — REBOOTING"
echo "=================================================="

sudo reboot
