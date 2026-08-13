## ignition

Fetches the fcos/ignition config served by the IronCore boot-operator and
applies its `passwd.users` and `storage.files` on first boot of the installed
system.

Meant to be combined with `metal` (and `disk-install`). Ubuntu/Debian do not
ship ignition natively (unlike GardenLinux, which carries it as a dracut
module), so this profile provides the same capability as a set of first-boot
systemd services, mirroring the `ironcore` profile's structure.

### How ignition reaches the machine

The `boot-operator` exposes the ignition config bound to a server at:

```
${BOOT_OPERATOR_BASE_URL}/ignition/<system-uuid>
```

where `<system-uuid>` is the server's SMBIOS product UUID
(`/sys/class/dmi/id/product_uuid`). The endpoint is only populated while a
`ServerClaim` with an `ignitionSecretRef` is bound to that server, and boot-
operator converts the served config to the fcos spec 3.x schema (camelCase
fields: `passwordHash`, `sshAuthorizedKeys`, `shell`, ...).

### The boot-operator address

There is no dynamic discovery of boot-operator's address: it is not on the
kernel cmdline (`HTTPBootConfig.spec` has no cmdline field), not in SMBIOS,
and not in the metaldata metadata. The machine must carry the address. It
lives in a single sourced config file so it's trivial to update:

```
mkosi.extra/etc/ignition/boot-operator.conf   # BOOT_OPERATOR_BASE_URL=...
```

Find the current value with:

```
kubectl -n boot-operator-system get svc boot-operator-service
```

If boot-operator gets a stable DNS name (e.g. via external-dns), swap the IPv6
literal in that conf file for the name — IPv6 literals keep their brackets,
DNS names don't.

### Supported config fields

`passwd.users[]`: `name`, `groups`, `passwordHash`, `sshAuthorizedKeys`,
`shell`.
`storage.files[]`: `path`, `mode`, `overwrite`, `user`, `group`, and
`contents.inline` / `contents.source`.

Everything else in the ignition spec is ignored (intentionally — same
trade-off the `ironcore` profile makes). Extend the scripts if you need more.

### Self-cleanup

After users and files are provisioned successfully, `ignition-cleanup.service`
disables and removes the ignition first-boot integration (scripts, units, and
`/etc/ignition/boot-operator.conf`) from the system. This mirrors GardenLinux's
post-install cleanup (it removes its own ignition dracut config after install).

The cleanup is ordered `Requires=ignition-users.service ignition-files.service`,
so it only runs when provisioning fully succeeded — on failure the services are
left in place for debugging. `ConditionFirstBoot=yes` on the bootstrap target
also means the services never re-run after first boot regardless, so cleanup is
about tidiness (no boot-operator address or provisioning scripts left on a
production server) rather than correctness.
