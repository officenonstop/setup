#!/bin/bash

set -x

# --- Validate input ---
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <customer name> <prod/trial> <type/xsmall etc>"
  exit 1
fi

CONTAINER="$1"-"$2"-"$3"
POOL="${CONTAINER}-pool"
SWAP="${POOL}/swap"
CUSTOMER="${CONTAINER%%.*}"   # Extracts text before first dot

echo "🧹 Starting cleanup for container: ${CONTAINER}"
echo "   -> Pool: ${POOL}"
echo "   -> Swap: ${SWAP}"
echo "   -> Profile: ${CUSTOMER}"
echo

if lxc list --format csv -c n | grep -Fxq "$CONTAINER"; then
  echo "✅ Container '$CONTAINER' exists."
else
  echo "❌ Container '$CONTAINER' not found."
  exit 1
fi

lxc delete "$CONTAINER" --force
sudo swapoff /dev/zvol/"$POOL"/swap
sudo zfs destroy "$POOL"/swap
lxc profile delete "$CONTAINER"
lxc storage delete "$POOL"
rm -f ~/.config/fish/functions/"$1"-"$2".fish

#lxc config device remove ${CONTAINER} myport8080

echo
echo "✅ Cleanup complete for $CONTAINER."
