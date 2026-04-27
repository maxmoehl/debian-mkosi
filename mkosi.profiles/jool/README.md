# jool

Adds [Jool](https://nicmx.github.io/Jool/) for stateful NAT64 translation
(`pool6 64:ff9b::/96`). Includes DKMS kernel module and userspace tools.

Overrides the base network config with a static configuration. IPv4 and IPv6
addresses are provided at boot via SMBIOS type 11 OEM strings:

```
-smbios type=11,value=ip4=192.168.1.2/24,value=ip6=2001:db8::2/64
```

The `smbios-network-config.service` reads these strings before networkd starts
and writes a networkd drop-in with the addresses. Both `ip4=` and `ip6=` are
required.
