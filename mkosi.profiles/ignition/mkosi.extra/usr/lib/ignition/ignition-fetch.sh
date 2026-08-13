#!/bin/bash
set -euo pipefail

CONF="/etc/ignition/boot-operator.conf"
if [ ! -r "${CONF}" ]; then
    echo "error: missing ${CONF}" >&2
    exit 1
fi
# shellcheck source=/etc/ignition/boot-operator.conf
. "${CONF}"

if [ -z "${BOOT_OPERATOR_BASE_URL:-}" ]; then
    echo "error: BOOT_OPERATOR_BASE_URL not set in ${CONF}" >&2
    exit 1
fi

# boot-operator keys the ignition config on the server's SMBIOS product UUID.
if [ ! -r /sys/class/dmi/id/product_uuid ]; then
    echo "error: cannot read SMBIOS product UUID" >&2
    exit 1
fi
SYSTEM_UUID="$(cat /sys/class/dmi/id/product_uuid)"

IGNITION_URL="${BOOT_OPERATOR_BASE_URL}/ignition/${SYSTEM_UUID}"

mkdir -p /run/ignition

echo "Fetching ignition config from ${IGNITION_URL}"
curl -sf --retry 5 --retry-delay 2 -o /run/ignition/config.ign "${IGNITION_URL}"

if [ ! -s /run/ignition/config.ign ]; then
    echo "error: ignition config is empty (no ServerClaim bound to this server?)" >&2
    exit 1
fi

echo "Fetched ignition config ($(wc -c < /run/ignition/config.ign) bytes)"
