# disk-install

Enables `MakeInitrd=yes` so the rootfs is packed as a cpio initrd. On boot,
systemd enters initrd mode and the `disk-install.service` runs before the system
would normally switch-root.

The install script (`/usr/local/bin/disk-install.sh`):

1. Selects the first PCI-attached disk
2. Cleans stale EFI boot entries
3. Partitions the disk (ESP + root) via `systemd-repart`
4. Writes `/etc/fstab`, `/etc/machine-id`, and `/etc/kernel/cmdline`
5. Installs `systemd-boot` and generates an initramfs
6. kexecs into the installed system's kernel

The rootfs copied to disk is read directly from `/` in the initrd, which is
clean since nothing has written to it at that point.
