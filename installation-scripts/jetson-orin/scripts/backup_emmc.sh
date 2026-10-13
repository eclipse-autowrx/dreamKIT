#!/usr/bin/env bash
# Backup the internal eMMC root filesystem (/dev/mmcblk0p1) to a tar.gz archive.
# Safe to run while the system is live: --one-file-system skips /proc, /sys,
# /dev, /run, tmpfs /tmp, and any other mounted filesystems (e.g. the SSD
# destination itself), so only the actual eMMC root content is archived.
set -euo pipefail

SOURCE_DIR="${1:-/}"
DEST_DIR="${2:-/media/sdv-orin/dfaf6380-658e-432a-b2d4-8efefec147a4/backups}"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (sudo $0 [source] [dest_dir])." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$DEST_DIR/mmcblk0p1_backup_${TIMESTAMP}.tar.gz"
LOG_FILE="$DEST_DIR/mmcblk0p1_backup_${TIMESTAMP}.log"

SRC_USED_HUMAN=$(df -h "$SOURCE_DIR" | tail -1 | awk '{print $3}')

echo "Source:      $SOURCE_DIR (~${SRC_USED_HUMAN} used)"
echo "Destination: $BACKUP_FILE"
echo "Log:         $LOG_FILE"
echo

tar --one-file-system --xattrs --acls --numeric-owner -czpf "$BACKUP_FILE" \
  -C "$SOURCE_DIR" . > "$LOG_FILE" 2>&1 &
TAR_PID=$!

while kill -0 "$TAR_PID" 2>/dev/null; do
  if [[ -f "$BACKUP_FILE" ]]; then
    CUR_SIZE=$(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1)
    printf "\r  ... %-10s written so far (source has ~%s used)   " "$CUR_SIZE" "$SRC_USED_HUMAN"
  fi
  sleep 5
done

set +e
wait "$TAR_PID"
STATUS=$?
set -e
echo

if [[ $STATUS -eq 0 ]]; then
  echo "Backup complete: $BACKUP_FILE"
  du -h "$BACKUP_FILE"
  echo "Restore later with: sudo ./restore_emmc.sh \"$BACKUP_FILE\" /dev/mmcblk0p1"
else
  echo "Backup FAILED (exit $STATUS). See $LOG_FILE" >&2
  exit "$STATUS"
fi
