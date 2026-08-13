## cloud-init

Provisions the machine with real cloud-init as an alternative to the `ironcore`
profile's custom services.

Ships a small out-of-tree datasource (`DataSourceIronCore` in
`/usr/lib/python3/dist-packages/ironcore_cloudinit/`, registered via
`datasource_pkg_list` in `/etc/cloud/cloud.cfg.d/99-ironcore.cfg`) which fetches
`http://metaldata.ironcore.dev/v1/` on every boot with the `Metadata-Flavor:
IronCore Metal` header in cloud-init's network stage, after systemd-networkd has
acquired a lease.

### User Data

Supply the `cloud-init` key in the metaldata `user-data` object. Its value is
used verbatim as cloud-init user-data, i.e. standard formats that any cloud user
already knows: `#cloud-config`, `#!` scripts, `#include`, or MIME multipart. The
value must start with the type header on the very first byte (no leading blank
line).

```json
{
  "user-data": {
    "cloud-init": "#cloud-config\nusers:\n  - name: max\n    groups: [sudo]\n    ssh_authorized_keys:\n      - ssh-ed25519 AAAA...\npackages:\n  - htop\n"
  },
  "server-name": "web1"
}
```

If the key is absent, the datasource reports "not found" and cloud-init does
nothing (falls through to the `None` datasource).

### Meta-Data

Synthesized on the client side; metaldata needs no changes:

- `server-name` becomes `local-hostname` (cloud-init sets the hostname).
- `instance-id` is the DMI product UUID, with `/etc/machine-id` as fallback.
  Per-instance modules re-run when it changes, for the machine-id fallback that
  happens automatically on reinstall; when two machines share a product UUID,
  per-instance state follows the install.

### Notes

- cloud-init's network rendering is disabled (`network: {config: disabled}`);
  systemd-networkd owns the network via 99-default.network.
- The distribution default user is disabled (`users: []`); define users in the
  supplied cloud-config instead.
- All cloud-init units carry `ConditionPathExists=!/etc/initrd-release` so
  nothing runs during the `disk-install` installer boot; cloud-init only starts
  in the installed system after kexec.
- The datasource hooks cloud-init's internal datasource API. It is pinned
  against the distro-shipped cloud-init; review on major upgrades.

### Usage

```
mkosi -p debian,metal,disk-install,cloud-init build
```

Or via bin/build with the `metal-cloudinit` flavor.

### Development with QEMU

No real server needed: boot the `virt` variant under QEMU and point the
datasource at `bin/metaldata-mock` running on the host. In QEMU user networking
the host is reachable as `10.0.2.2`.

```console
# Host: mock metaldata (re-reads the file on every request)
$ bin/metaldata-mock &

# Host: local dev overlay (not committed) — metadata URL override
$ mkdir -p dev/etc/cloud/cloud.cfg.d
$ cat > dev/etc/cloud/cloud.cfg.d/98-dev.cfg <<EOF
datasource:
  IronCore:
    metadata_url: "http://10.0.2.2:8080/v1/"
EOF

# Host: ssh credentials for `mkosi ssh` (once; keep out of git)
$ mkosi genkey

# Host: build & boot (serial console)
$ mkosi -p debian,virt,cloud-init --extra-tree=$PWD/dev build
$ mkosi -p debian,virt,cloud-init vm
```

Modern mkosi does not forward a TCP port for ssh; instead the guest's sshd is
exposed over vsock (via systemd-ssh-generator, systemd v256+) and mkosi
provisions the mkosi.crt certificate as root's authorized_keys when the VM
starts. Log in from a second terminal with the same config:

```console
$ mkosi -p debian,virt,cloud-init --extra-tree=$PWD/dev ssh
```

If vsock ssh does not work on your setup, fall back to manual qemu with `-netdev
user,id=n0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=n0`, drop your
pubkey into dev/root/.ssh/authorized_keys (via --extra-tree) and `ssh -p 2222
root@localhost`.

Fast inner loop (build the image once):

- user-data changes: edit the JSON given to metaldata-mock (no restart needed),
  then in the VM: `cloud-init clean --logs && reboot`. A boot takes seconds, so
  a full apply cycle is ~30s.
- datasource code changes: push the file into the running VM and do the same:

  ```console
  $ mkosi -p debian,virt,cloud-init --extra-tree=$PWD/dev ssh -- \
        tee /usr/lib/python3/dist-packages/ironcore_cloudinit/sources/DataSourceIronCore.py \
        < mkosi.profiles/cloud-init/.../DataSourceIronCore.py
  ```

  (or scp over the forwarded port with the manual-qemu fallback)

- `cloud-init status --long`, `/var/log/cloud-init.log` and `cloud-init query
  ds` inside the VM tell you what the datasource saw.

End-to end check without a server: build `-p debian,metal,disk-install,cloud-init`
(with the same overlay), boot the UKI in QEMU with a blank disk attached; the
installer picks the first PCI disk, installs, kexecs, and cloud-init runs
against the mock in the installed system.
