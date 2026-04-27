# IronCore Debian Image

Minimal Debian (trixie) image built with [mkosi](https://github.com/systemd/mkosi),
packaged as a Unified Kernel Image (UKI) for HTTP boot and iPXE.

## Building

Host dependencies: `mkosi`

Profiles are combined to produce the desired image variant. A kernel profile
(`metal` or `virt`) is always required:

```
mkosi -p metal,users,frr build
mkosi -p virt,jool build
mkosi -p metal,disk-install build
```

Output is placed in `mkosi.output/`. The UKI is the `.efi` file.

## Profiles

| Profile        | Purpose                                                 |
|----------------|---------------------------------------------------------|
| `metal`        | Full hardware kernel (`linux-image-amd64`), VGA console |
| `virt`         | Cloud kernel (`linux-image-cloud-amd64`), serial console|
| `disk-install` | Boots as initrd, installs to disk, kexecs               |
| `users`        | Creates operator accounts (max, damyan) with SSH keys   |
| `frr`          | Adds FRRouting                                          |
| `jool`         | Adds Jool NAT64 with SMBIOS-driven network config       |

## Boot Modes

**Live boot** (any profile except `disk-install`): the UKI boots directly into
the in-memory rootfs. No initrd phase, no switch-root — systemd starts normally
on a writable tmpfs.

**Disk install** (`disk-install` profile): the rootfs is packed as a cpio initrd
(`MakeInitrd=yes`). systemd enters initrd mode, the install service partitions
the target disk, copies the clean rootfs, installs the bootloader, and kexecs
into the installed system.

## Publishing

```
ironcore-image build --tag "${IMAGE_TAG}" \
    --config "arch=amd64,uki=mkosi.output/ironcore-debian.efi"
ironcore-image push --push-sub-manifests "${IMAGE_TAG}"
```

Requires `ironcore-image` and registry credentials.
