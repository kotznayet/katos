sudo apt update && sudo apt upgrade -y
sudo apt install plasma-desktop sddm plasma-workspace kwin-wayland upower udisks2 plasma-nm kscreen partitionmanager chromium -y --no-install-recommends
sudo apt install gldriver-test dolphin konsole kdialog kate vlc kde-config-sddm bluedevil plasma-browser-integration wget -y --no-install-recommends
yes | sh -c "$(wget https://raw.githubusercontent.com/Botspot/pi-apps/master/install -O -)"
yes | sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
sudo systemctl enable sddm.service 
sudo systemctl set-default graphical.target
sudo systemctl start sddm.service
# Please run this on debian or raspberry pi os lite. Maybe ubuntu server and diet pi would work too. Run with ssh or locally after first boot, please don't run with raspi connect.
