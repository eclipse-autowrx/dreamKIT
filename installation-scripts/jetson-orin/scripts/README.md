# eMMC Backup / Restore (Jetson AGX Orin)

Scripts to back up the internal eMMC root filesystem to the NVMe SSD, and
restore it later — either back onto the eMMC, or onto the SSD to boot from
NVMe instead.

Tested on: Jetson AGX Orin Devkit, L4T R35.4.1 (JetPack 5.1.x), UEFI +
`extlinux.conf` boot flow.

## Files

| Script              | Purpose                                                |
|---------------------|---------------------------------------------------------|
| `backup_emmc.sh`     | Archive the live root filesystem to a `.tar.gz`         |
| `restore_emmc.sh`    | Format a target partition and extract a backup onto it  |

## How the current layout looks on this board

- `/dev/mmcblk0p1` — internal eMMC, currently mounted as `/` (the running root fs)
- `/dev/nvme0n1p1` — NVMe SSD, mounted at
  `/media/sdv-orin/dfaf6380-658e-432a-b2d4-8efefec147a4` (the mount path is
  keyed to this specific SSD's UUID and will differ on another drive)

Both disks carry a full L4T partition layout (EFI System Partition +
bootloader firmware partitions + a big ext4 root partition), because the SSD
was previously flashed for external NVMe boot via `flash.sh`/SDK Manager.
That boot infrastructure is what these scripts rely on — they only ever
touch the root filesystem's *content*, never the partition table, ESP, or
QSPI-resident UEFI firmware.

## Backup

Run as root, from a terminal (sudo will prompt for your password there —
never paste a password into chat/AI tools):

```bash
sudo ./backup_emmc.sh [source_dir] [dest_dir]
# defaults:
#   source_dir = /
#   dest_dir   = /media/sdv-orin/dfaf6380-658e-432a-b2d4-8efefec147a4/backups
```

- Safe to run while the system is live — `tar --one-file-system` automatically
  skips `/proc`, `/sys`, `/dev`, `/run`, tmpfs `/tmp`, and any other mounted
  filesystem (including the SSD destination itself), so only the actual eMMC
  content is archived.
- Prints a running "bytes written" progress line every 5s (no `pv`/`pigz`
  installed on this board, so no percentage bar).
- Output: `mmcblk0p1_backup_<timestamp>.tar.gz` + a `.log` file in `dest_dir`.

## Restore

```bash
sudo ./restore_emmc.sh <backup_file.tar.gz> [target_partition]
# target_partition defaults to /dev/mmcblk0p1
```

**Destructive** — reformats `target_partition` as ext4 and overwrites it. The
script:
- refuses to run if `target_partition` is the currently-booted root device
  (you must boot from other media — recovery mode / live USB — to restore
  over the eMMC you're running from)
- requires typing `YES` to confirm
- after extracting, rewrites `root=/dev/...` in the restored
  `/boot/extlinux/extlinux.conf` to point at `target_partition` (saving the
  original as `extlinux.conf.bak`) — this matters whenever you restore onto a
  *different* device than the backup came from (see below)

### Restore onto the same device (eMMC → eMMC)

Boot from other media, then:

```bash
sudo ./restore_emmc.sh /path/to/mmcblk0p1_backup_<timestamp>.tar.gz /dev/mmcblk0p1
```

### Restore onto the SSD instead (to boot from NVMe)

```bash
sudo ./restore_emmc.sh /path/to/mmcblk0p1_backup_<timestamp>.tar.gz /dev/nvme0n1p1
```

This only works if the SSD **already has a valid partition table + ESP +
bootloader chain** (true on this board today — confirmed by its own
pre-existing `/boot/extlinux/extlinux.conf`). If the SSD's GPT were ever
wiped, a tar restore can't recreate it — you'd need a full reflash via
`flash.sh`/SDK Manager targeting NVMe first (from a host PC, Jetson in Force
Recovery Mode), *then* restore the tar backup on top of the resulting
partition to bring back the customized OS content.

After restoring onto the SSD, the Jetson still won't boot from it until you
change the boot priority — restoring files never changes that:

- **At the console**: attach a display + keyboard (or serial console), power
  on, and press `Esc` repeatedly at boot to enter the UEFI setup menu. Under
  something like *Device Manager → NVIDIA Configuration Menu → L4T
  Configuration*, set NVMe ahead of eMMC in boot priority. (Exact wording can
  vary slightly by firmware build.)
- **Remotely**: `sudo apt install efibootmgr`, then `efibootmgr -v` to list
  UEFI boot entries and `efibootmgr -o <nvme-id>,<other-ids>` to reorder
  `BootOrder` without touching the console — only works if the SSD already
  registered its own UEFI boot entry (it should have, from its original
  flash).

## Limitations

- File-level backup only: does **not** capture the QSPI/UEFI firmware, GPT
  partition table, or ESP contents. It cannot make a genuinely blank,
  never-flashed Jetson bootable — that always requires an initial
  `flash.sh`/SDK Manager flash from a host PC first.
- `root=` device is auto-corrected on restore, but any other
  device-specific config referencing `/dev/mmcblk0p1` elsewhere in the
  backed-up files (e.g. `/etc/fstab` entries) is restored as-is and may need
  manual review after a cross-device restore.
