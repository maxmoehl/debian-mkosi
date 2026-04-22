#!/bin/bash
set -euo pipefail

ROOTFS="/rootfs"

# --- Target disk selection ---

# WARNING: make sure you don't have a virtual media mounted via the BMC
# as that will appear as the first device.
target=""
for disk in /dev/disk/by-path/pci-*; do
    [ -e "${disk}" ] || continue
    target=$(readlink -f "${disk}")
    break
done

if [ -z "${target}" ]; then
    echo "error: no disk found under /dev/disk/by-path/pci-*" >&2
    exit 1
fi

echo "Installing to ${target}"

# --- Clean EFI boot entries ---

for entry in $(efibootmgr | awk '$NF ~ /^HD/ { print $1 }' | sed 's/Boot\([0-9A-F]*\)./\1/'); do
    echo "Removing EFI boot entry ${entry}"
    efibootmgr -B -b "${entry}" > /dev/null
done

# --- Wipe and partition ---

REPART_DIR=$(mktemp -d)
trap 'rm -rf "${REPART_DIR}"' EXIT

cat > "${REPART_DIR}/00-esp.conf" <<EOF
[Partition]
Type=esp
Format=vfat
SizeMinBytes=512M
SizeMaxBytes=512M
Label=ESP
MountPoint=/efi
EOF

cat > "${REPART_DIR}/10-root.conf" <<EOF
[Partition]
Type=root
SizeMinBytes=20G
CopyFiles=/
CopyFiles=/boot
Label=ROOT
MountPoint=/
EOF

systemd-repart \
    --empty=force \
    --definitions="${REPART_DIR}" \
    --discard=false \
    --json=pretty \
    --dry-run=off \
    --copy-source="${ROOTFS}" \
    "${target}"

udevadm settle

# --- Post-install configuration ---

MNT="/mnt"
mount /dev/disk/by-label/ROOT "${MNT}"
mount /dev/disk/by-label/ESP "${MNT}/efi"

cat > "${MNT}/etc/fstab" <<EOF
LABEL=ROOT      /               ext4            errors=remount-ro 0       1
LABEL=ESP       /efi            vfat            umask=0077        0       1
EOF

echo "uninitialized" > "${MNT}/etc/machine-id"

rm -f "${MNT}/etc/initrd-release"

mkdir -p "${MNT}/etc/kernel"
echo "root=LABEL=ROOT console=tty0" > "${MNT}/etc/kernel/cmdline"

rmdir "${MNT}/sysroot" 2>/dev/null || true

# --- Install bootloader ---

mount -t proc proc "${MNT}/proc"
mount -t sysfs sysfs "${MNT}/sys"
mount --bind /dev "${MNT}/dev"
mount --bind /sys/firmware/efi/efivars "${MNT}/sys/firmware/efi/efivars"

chroot "${MNT}" bootctl install
chroot "${MNT}" update-initramfs -c -k "$(uname -r)"

umount "${MNT}/sys/firmware/efi/efivars"
umount "${MNT}/dev"
umount "${MNT}/sys"
umount "${MNT}/proc"
umount "${MNT}/efi"
umount "${MNT}"

echo "Installation complete. Reboot to boot from disk."
