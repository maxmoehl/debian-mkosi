#!/bin/bash
set -euo pipefail

METADATA="/run/ironcore/metadata.json"

hostname=$(jq -r '.["server-name"] // empty' "${METADATA}")
if [ -z "${hostname}" ]; then
    echo "No server-name in metadata, nothing to do"
    exit 0
fi

hostnamectl set-hostname "${hostname}"
echo "Set hostname to ${hostname}"
