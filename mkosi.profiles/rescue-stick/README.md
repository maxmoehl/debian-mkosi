## rescue-stick

This should be a separate repo but I'm lazy.


### Testing

To test the image with qemu, you need to add `console=ttyS0` to the kernel
cmdline to be able to attach to the VM via the qemu serial console:

```
mkosi --profile metal,rescue-stick --kernel-command-line console=ttyS0 build
```

To run in qemu:

```
qemu-system-x86_64 \
    -m 2G \
    -bios /usr/share/ovmf/OVMF.fd \
    -drive file=mkosi.output/image.raw,format=raw,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0 \
    -nographic \
    -enable-kvm
```

Drop the `-enable-kvm` to be able to run without any privileges.
