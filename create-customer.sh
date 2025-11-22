#!/bin/bash

set -e
set -x

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <customer_name> <type> <size>"
  echo "Type: prod, trial"
  echo "Valid sizes: tiny, xsmall, small, medium, large, xlarge"
  exit 1
fi

CUSTOMER_NAME=$1
TYPE=$2
SIZE=$3

VALID_TYPES=("prod" "trial")
if [[ ! " ${VALID_TYPES[*]} " =~ " ${TYPE} " ]]; then
  echo "Error: Invalid type '${TYPE}'."
  echo "Valid sizes: ${VALID_TYPES[*]}"
  exit 1
fi

VALID_SIZES=("tiny" "xsmall" "small" "medium" "large" "xlarge")
if [[ ! " ${VALID_SIZES[*]} " =~ " ${SIZE} " ]]; then
  echo "Error: Invalid size '${SIZE}'."
  echo "Valid sizes: ${VALID_SIZES[*]}"
  exit 1
fi

CONTAINER_NAME="${CUSTOMER_NAME}-${TYPE}-${SIZE}"

# --- Define resource configurations for each size ---
case "$SIZE" in
  tiny)
    CPU_ALLOWANCE="50%"
    MEM_LIMIT="1GB"
    DISK_POOL="${CONTAINER_NAME}-pool"
    DISK_SIZE="20GB"
    ;;
  xsmall)
    CPU_ALLOWANCE="100%"
    MEM_LIMIT="1500MB"
    DISK_POOL="${CONTAINER_NAME}-pool"
    DISK_SIZE="20GB"
    ;;
  small)
    CPU_ALLOWANCE="200%"
    MEM_LIMIT="2GB"
    DISK_POOL="${CONTAINER_NAME}-pool"
    DISK_SIZE="20GB"
    ;;
  medium)
    CPU_ALLOWANCE="400%"
    MEM_LIMIT="4GB"
    DISK_POOL="${CONTAINER_NAME}-pool"
    DISK_SIZE="25GB"
    ;;
  large)
    CPU_ALLOWANCE="800%"
    MEM_LIMIT="8GB"
    DISK_POOL="${CONTAINER_NAME}-pool"
    DISK_SIZE="50GB"
    ;;
  xlarge)
    CPU_ALLOWANCE="1600%"
    MEM_LIMIT="16GB"
    DISK_POOL="${CONTAINER_NAME}-pool"
    DISK_SIZE="100GB"
    ;;
esac

lxc storage create "${CONTAINER_NAME}-pool" zfs size="${DISK_SIZE}"
sudo zfs create -V 2G -b 4K -o compression=off -o sync=always -o primarycache=metadata "${CONTAINER_NAME}-pool"/swap
sudo mkswap -f /dev/zvol/"${CONTAINER_NAME}-pool"/swap
sudo swapon /dev/zvol/"${CONTAINER_NAME}-pool"/swap
echo '/dev/zvol/"${CONTAINER_NAME}-pool"/swap none swap defaults 0 0' | sudo tee -a /etc/fstab


echo -e "name: "$CONTAINER_NAME"\nconfig:\n  limits.cpu.allowance: "$CPU_ALLOWANCE"\n  limits.memory: "$MEM_LIMIT"\ndevices:\n  root:\n    path: /\n    pool: "$DISK_POOL"\n    size: "$DISK_SIZE"\n    type: disk\n  eth0:\n    name: eth0\n    network: lxdbr0\n    type: nic\nused_by: []\nproject: default" > "$CONTAINER_NAME".yaml
lxc profile create "$CONTAINER_NAME" < "$CONTAINER_NAME".yaml

# --- Launch command ---
echo "🚀 Launching container '${CONTAINER_NAME}' (size: ${SIZE}) ..."
lxc launch ubuntu/24.04 "$CONTAINER_NAME" --profile "$CONTAINER_NAME" --config 'security.nesting=true'
#wait so lxc can start container successfully
wait 10

fish -c "alias $CUSTOMER_NAME-$TYPE-$SIZE 'lxc exec $CONTAINER_NAME -- su - root'; funcsave  $CUSTOMER_NAME-$TYPE-$SIZE"

#stop snap to refresh ever
lxc exec "$CONTAINER_NAME" -- bash -c "sudo systemctl mask snapd.refresh.service"
lxc exec "$CONTAINER_NAME" -- bash -c "sudo systemctl mask snapd.refresh.timer"

#install fish, first fix hosts file and then install
lxc exec "$CONTAINER_NAME" -- bash -c "grep -q \$(hostname) /etc/hosts || echo '127.0.1.1 \$(hostname)' >> /etc/hosts"
lxc exec "$CONTAINER_NAME" -- bash -c "apt update -y && apt install -y fish; chsh -s /usr/bin/fish"

#install docker and start containers
lxc exec "$CONTAINER_NAME" -- bash -c "timedatectl set-timezone \"Asia/Kolkata\""
lxc exec "$CONTAINER_NAME" -- bash -c "git clone https://github.com/officenonstop/erp --branch generic_v15 --single-branch"
lxc exec "$CONTAINER_NAME" -- bash -c "snap install docker"
#wait for docker to come up
sleep 10
lxc exec "$CONTAINER_NAME" -- bash -c "docker compose -f /root/erp/my.yml up --timestamps --force-recreate -d"

#Dont use below, setup nginx as reverse proxy
#lxc config device add ${CONTAINER_NAME} myport8080 proxy listen=tcp:0.0.0.0:8080 connect=tcp:127.0.0.1:8080

echo
echo "✅ Container '${CONTAINER_NAME}' created successfully! Use customername to switch to its container."
lxc list | grep "$CONTAINER_NAME"

