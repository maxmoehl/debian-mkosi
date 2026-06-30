## metal

Produces a UKI which can be booted on bare-metal hosts via the IronCore metal
automation.

Full hardware kernel (`linux-image-amd64`) for bare-metal machines. Sets the
console to VGA (`console=tty0`). Provides a networkd config for physical
interfaces.

By default, the image is set up for live-booting over the network. See the
`disk-install` profile for installing to the servers disk.

### Publishing as OCI

IronCore consumes images from OCI registries. A built UKI can be published as an
OCI image like this:

```
ironcore-image build --tag "${IMAGE_TAG}" \
    --config "arch=$ARCH,uki=mkosi.output/$IMAGE.efi"
ironcore-image push --push-sub-manifests "${IMAGE_TAG}"
```

See the documentation of ironcore-image for the full list of options.
