#!/bin/bash
set -euo pipefail

METADATA="/run/ironcore/metadata.json"

users_raw=$(jq -r '.["user-data"].users // empty' "${METADATA}")
if [ -z "${users_raw}" ]; then
    echo "No users in metadata, nothing to do"
    exit 0
fi

echo "${users_raw}" | jq -c '.[]' | while IFS= read -r user; do
    name=$(echo "${user}" | jq -r '.name')

    args=()

    mapfile -t groups < <(echo "${user}" | jq -r '(.groups // []) | .[]')
    if [ ${#groups[@]} -gt 0 ]; then
        for group in "${groups[@]}"; do
            if ! getent group "${group}" &>/dev/null; then
                groupadd "${group}"
            fi
        done
        args+=(--groups "$(IFS=,; echo "${groups[*]}")")
    fi

    password_hash=$(echo "${user}" | jq -r '.password_hash // empty')
    if [ -n "${password_hash}" ]; then
        args+=(--password "${password_hash}")
    fi

    if ! id "${name}" &>/dev/null; then
        useradd --create-home --shell /bin/bash "${args[@]}" "${name}"
        echo "Created user ${name}"
    else
        if [ ${#args[@]} -gt 0 ]; then
            usermod "${args[@]}" "${name}"
            echo "Updated user ${name}"
        fi
    fi

    mapfile -t ssh_keys < <(echo "${user}" | jq -r '(.ssh_keys // []) | .[]')
    if [ ${#ssh_keys[@]} -gt 0 ]; then
        home=$(getent passwd "${name}" | cut -d: -f6)
        ssh_dir="${home}/.ssh"
        mkdir -p "${ssh_dir}"
        printf '%s\n' "${ssh_keys[@]}" > "${ssh_dir}/authorized_keys"
        chmod 700 "${ssh_dir}"
        chmod 600 "${ssh_dir}/authorized_keys"
        chown -R "${name}:" "${ssh_dir}"
        echo "Wrote ${#ssh_keys[@]} SSH key(s) for ${name}"
    fi
done
