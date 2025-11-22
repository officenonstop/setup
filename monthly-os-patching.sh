sudo apt update
sudo apt upgrade --with-new-pkgs
lxc stop --all
docker stop $(docker ps -q)
reboot