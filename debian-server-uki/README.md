# Debian Live Image (ironcore)

Minimal Debian image built with [mkosi](https://github.com/systemd/mkosi),
packaged as a Unified Kernel Image (UKI) for HTTP boot and iPXE.

## Overview

The image boots entirely from memory. mkosi packs the full rootfs as a cpio
archive into the UKI's `.initrd` PE section. On boot, the kernel unpacks this
into an initramfs (tmpfs). Custom systemd units then remount the initramfs
read-only and set up an overlayfs with a tmpfs upper layer, preserving a clean
copy of the rootfs for disk installation.

## Boot Flow

1. Firmware or iPXE loads and executes the UKI (`ironcore-debian.efi`)
2. The systemd EFI stub extracts kernel, initrd (rootfs cpio), and cmdline
3. Kernel unpacks the cpio into initramfs, starts systemd in initrd mode (`MakeInitrd=yes`)
4. `remount-rootfs-ro.service` — remounts `/` read-only
5. `create-overlay-dirs.service` — creates overlay work directories on `/run`
6. `sysroot.mount` — mounts overlayfs at `/sysroot` (lower=`/`, upper=tmpfs)
7. `sysroot-prepare.service` — removes `/etc/initrd-release` from the overlay and creates the `/rootfs` mount point
8. `sysroot-rootfs.mount` — bind-mounts `/` (read-only initrd) to `/sysroot/rootfs`
9. `ic-end.service` — runs install script from `/sysroot/ironcore.initrd.end` if present
10. systemd switch-roots to `/sysroot`

After switch-root, `/` is the overlay (writable, volatile) and `/rootfs`
is the clean rootfs for disk installation. The bind mount at `/rootfs`
survives switch-root because it is a submount of `/sysroot`.

All overlay-related units are conditioned on `ConditionKernelCommandLine=ic.ovl`
and only activate when the `ic.ovl` flag is present on the kernel command line.

## Kernel Command Line Flags

| Flag      | Purpose                                           |
|-----------|---------------------------------------------------|
| `ic.ovl`  | Activates the read-only rootfs + overlay setup    |

## Building

Host dependencies: `mkosi`

```
mkosi build
```

The output from the build will be placed in `mkosi.output/`, the UKI is the file
named `mkosi.output/ironcore-debian.efi`.

## Publishing

```
ironcore-image build --tag "${IMAGE_TAG}" \
    --config "arch=amd64,uki=mkosi.output/ironcore-debian.efi"
ironcore-image push --push-sub-manifests "${IMAGE_TAG}"
```

This builds the OCI image, wraps it with `ironcore-image`, and pushes to the
registry. Requires `ironcore-image` and registry credentials.

## Disk Installation

From the live-booted system, the clean rootfs at `/rootfs` can be copied to
disk. The install flow partitions the target disk, copies the rootfs, installs a
bootloader, and reboots:

1. Partition the disk (ESP + root)
2. Format and mount the partitions
3. Copy from `/rootfs` to the target
4. Remove `/etc/initrd-release` from the target (the rootfs contains this file
   because it is built as an initrd; without removing it systemd enters initrd
   mode on disk boot)
5. Write `uninitialized` to `/etc/machine-id` on the target (the image ships
   an empty file for transient live-boot IDs; the installed system needs
   `uninitialized` so systemd generates a persistent ID on first boot)
6. Write `/etc/fstab` and `/etc/kernel/cmdline`
7. `chroot` and run `bootctl install` + `update-initramfs`
8. Reboot

This can be automated via the `ic-end.service` hook by placing an install script
at `/ironcore.initrd.end` in the image, a working installer is also provided
within the image at `/usr/local/bin/install.sh`.
