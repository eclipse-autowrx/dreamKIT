#!/usr/bin/env bash
# Restore a tar.gz backup (made by backup_emmc.sh) onto a target partition.
# DESTRUCTIVE: reformats the target partition and overwrites its contents.
# Must be run from media OTHER than the target partition itself (e.g. a
# recovery/live USB) - you cannot restore over the filesystem you booted from.
set -euo pipefail

usage() {
  echo "Usage: sudo $0 <backup_file.tar.gz> [target_partition]" >&2
  echo "  target_partition defaults to /dev/mmcblk0p1" >&2
  exit 1
}

BACKUP_FILE="${1:-}"
TARGET_DEV="${2:-/dev/mmcblk0p1}"

[[ -z "$BACKUP_FILE" ]] && usage
[[ -f "$BACKUP_FILE" ]] || { echo "Backup file not found: $BACKUP_FILE" >&2; exit 1; }
[[ -b "$TARGET_DEV" ]] || { echo "Not a block device: $TARGET_DEV" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

ROOT_DEV=$(findmnt -no SOURCE / || true)
if [[ "$TARGET_DEV" == "$ROOT_DEV" ]]; then
  echo "ERROR: $TARGET_DEV is the currently running root filesystem." >&2
  echo "Boot from other media (recovery mode / live USB) before restoring over it." >&2
  exit 1
fi

echo "WARNING: this will ERASE ALL DATA on $TARGET_DEV and restore:"
echo "  $BACKUP_FILE"
read -rp "Type 'YES' (all caps) to continue: " CONFIRM
[[ "$CONFIRM" == "YES" ]] || { echo "Aborted."; exit 1; }

MNT=$(mktemp -d)
cleanup() { umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

echo "Formatting $TARGET_DEV as ext4..."
mkfs.ext4 -F "$TARGET_DEV"

mount "$TARGET_DEV" "$MNT"

echo "Extracting backup onto $TARGET_DEV (this can take a while)..."
tar --numeric-owner -xzpf "$BACKUP_FILE" -C "$MNT"

# The backup carries whatever root= device its source had baked into
# extlinux.conf. When restoring onto a *different* device (e.g. an eMMC
# backup restored onto an NVMe partition for SSD boot), that line must be
# repointed at TARGET_DEV or the kernel will look for the wrong root disk.
EXTLINUX="$MNT/boot/extlinux/extlinux.conf"
if [[ -f "$EXTLINUX" ]] && grep -q '^\s*APPEND' "$EXTLINUX"; then
  if grep -qE "root=$TARGET_DEV(\s|\$)" "$EXTLINUX"; then
    echo "extlinux.conf already points at $TARGET_DEV, leaving it as-is."
  else
    cp "$EXTLINUX" "$EXTLINUX.bak"
    sed -i -E "s#root=/dev/[A-Za-z0-9]+#root=$TARGET_DEV#g" "$EXTLINUX"
    echo "Updated extlinux.conf root= to $TARGET_DEV (original saved as extlinux.conf.bak)."
  fi
else
  echo "NOTE: no /boot/extlinux/extlinux.conf found in the backup - if this device" >&2
  echo "needs one to boot, restore/create it manually before rebooting." >&2
fi

sync
echo "Restore complete on $TARGET_DEV. Reboot to use it."
echo
echo "If TARGET_DEV is not the eMMC (e.g. you restored onto the NVMe SSD for SSD"
echo "boot), you also need to change which storage device the Jetson boots from"
echo "(UEFI boot order / L4T boot priority) - this script only restores files."
