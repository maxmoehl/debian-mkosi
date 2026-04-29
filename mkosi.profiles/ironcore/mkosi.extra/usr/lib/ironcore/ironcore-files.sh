#!/bin/bash
set -euo pipefail

METADATA="/run/ironcore/metadata.json"

files_raw=$(jq -r '.["user-data"].files // empty' "${METADATA}")
if [ -z "${files_raw}" ]; then
    echo "No files in metadata, nothing to do"
    exit 0
fi

echo "${files_raw}" | jq -c '.[]' | while IFS= read -r entry; do
    path=$(echo "${entry}" | jq -r '.path')
    content=$(echo "${entry}" | jq -r '.content')
    owner=$(echo "${entry}" | jq -r '.owner // "root:root"')
    mode=$(echo "${entry}" | jq -r '.mode // "0644"')

    mkdir -p "$(dirname "${path}")"
    printf '%s' "${content}" > "${path}"
    chown "${owner}" "${path}"
    chmod "${mode}" "${path}"
    echo "Wrote ${path} (owner=${owner}, mode=${mode})"
done
