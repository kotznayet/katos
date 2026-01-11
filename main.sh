sudo apt update && sudo apt upgrade -y
sudo apt install plasma-desktop plasma-workspace sddm kwin-wayland -y --no-install-recommends
sudo apt install gldriver-test dolphin konsole kdialog vlc kde-config-sddm curl -y 
sh -c "$(curl -fsSL https://raw.githubusercontent.com/kotznayet/katos/master/tools/quiet-piapps.sh)"
sudo systemctl enable sddm.service 
sudo systemctl start sddm.service
