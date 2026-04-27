#!/bin/bash
set -euo pipefail

ipv4=""
ipv6=""
while IFS= read -r line; do
    line="${line#*: }"
    case "${line}" in
        ip4=*) ipv4="${line#ip4=}" ;;
        ip6=*) ipv6="${line#ip6=}" ;;
    esac
done < <(dmidecode -q -t 11)

if [ -z "${ipv4}" ] || [ -z "${ipv6}" ]; then
    echo "error: both ip4= and ip6= SMBIOS strings are required" >&2
    exit 1
fi

dropin="/run/systemd/network/99-default.network.d"
mkdir -p "${dropin}"

printf '[Address]\nAddress=%s\n\n[Address]\nAddress=%s\n' "${ipv4}" "${ipv6}" \
    > "${dropin}/10-smbios.conf"
