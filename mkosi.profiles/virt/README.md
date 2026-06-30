## virt

Produces a raw disk which can be booted in a VM.

Cloud-optimized kernel (`linux-image-cloud-amd64`) for virtual machines. Strips
hardware drivers not needed in VMs. Sets the console to serial
(`console=ttyS0,115200`).

### Publishing as OCI

IronCore consumes images from OCI registries. A built raw disk can be published
as an OCI image like this:

```
ironcore-image build --tag "${IMAGE_TAG}" \
    --config "arch=$ARCH,rootfs=mkosi.output/$IMAGE.raw"
ironcore-image push --push-sub-manifests "${IMAGE_TAG}"
```

See the documentation of ironcore-image for the full list of options.

### Testing in QEMUo

You can launch a VM directly from the `raw` disk image:

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

Drop the `-enable-kvm` to be able to run without any privileges. You should be
able to SSH into the machine:

```
ssh -p 2222 localhost
```
