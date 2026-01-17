sudo apt update && sudo apt upgrade -y
sudo apt install plasma-desktop sddm plasma-workspace kwin-wayland upower udisks2 plasma-nm kscreen partitionmanager -y --no-install-recommends
sudo apt install gldriver-test dolphin konsole kdialog kate vlc kde-config-sddm bluedevil plasma-browser-integration wget -y --no-install-recommends
wget -qO- https://raw.githubusercontent.com/Botspot/pi-apps/master/install | bash
yes | sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
sudo systemctl enable sddm.service 
sudo systemctl set-default graphical.target
sudo systemctl start sddm.service
