#!/bin/bash
set -x

sudo apt-add-repository -y ppa:fish-shell/release-3
timedatectl set-timezone "Asia/Kolkata"
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
apt-get update -yq
apt-get upgrade -yq
apt install -y git
apt install -y snapd
apt install -y zfsutils-linux
apt install -y fish
chsh -s /usr/bin/fish

sudo dpkg-reconfigure unattended-upgrades
sudo sh -c 'echo "SystemMaxUse=200M" >> /etc/systemd/journald.conf'
sudo sh -c 'echo "SystemMaxFileSize=50M" >> /etc/systemd/journald.conf'
sudo systemctl mask snapd.snap-repair.service
sudo systemctl mask snapd.snap-repair.timer
sudo snap set system refresh.hold="$(date --date='2100-01-01' +%Y-%m-%d)"
sudo systemctl mask snapd.refresh.service
sudo systemctl mask snapd.refresh.timer

snap install lxd --channel=6/stable
lxd init --minimal
# enter everywhere (12 time) except this one, say YES and enter>>
#Would you like the server to be available over the network? (yes/no) [default=no]: yes

#run below at root level from main VM, NOT INSIDE LXC container!!
#do below so UFW wont create issues for lxc and domain resolution
#below 3 needed so lxc containers will have ipv4 address
ufw allow in on lxdbr0
ufw route allow in on lxdbr0
ufw route allow out on lxdbr0
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh 
ufw allow 8080
ufw allow 9090
ufw --force enable
ufw reload

sleep 10
reboot
