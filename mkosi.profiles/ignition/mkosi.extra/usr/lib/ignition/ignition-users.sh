#!/bin/bash
set -euo pipefail

CONFIG="/run/ignition/config.ign"

if [ ! -s "${CONFIG}" ]; then
    echo "No ignition config, nothing to do"
    exit 0
fi

users_raw="$(jq -r '.passwd.users // empty' "${CONFIG}")"
if [ -z "${users_raw}" ]; then
    echo "No users in ignition config, nothing to do"
    exit 0
fi

echo "${users_raw}" | jq -c '.[]' | while IFS= read -r user; do
    name="$(jq -r '.name' <<<"${user}")"

    args=()

    # shell
    shell="$(jq -r '.shell // empty' <<<"${user}")"
    if [ -n "${shell}" ]; then
        args+=(--shell "${shell}")
    fi

    # groups (created if missing)
    mapfile -t groups < <(jq -r '(.groups // []) | .[]' <<<"${user}")
    if [ "${#groups[@]}" -gt 0 ]; then
        for group in "${groups[@]}"; do
            if ! getent group "${group}" &>/dev/null; then
                groupadd "${group}"
            fi
        done
        args+=(--groups "$(IFS=,; echo "${groups[*]}")")
    fi

    # password hash (fcos spec 3.x: passwordHash)
    password_hash="$(jq -r '.passwordHash // empty' <<<"${user}")"
    if [ -n "${password_hash}" ]; then
        args+=(--password "${password_hash}")
    fi

    if ! id "${name}" &>/dev/null; then
        useradd --create-home "${args[@]}" "${name}"
        echo "Created user ${name}"
    else
        if [ "${#args[@]}" -gt 0 ]; then
            usermod "${args[@]}" "${name}"
            echo "Updated user ${name}"
        fi
    fi

    # ssh authorized keys (fcos spec 3.x: sshAuthorizedKeys)
    mapfile -t ssh_keys < <(jq -r '(.sshAuthorizedKeys // []) | .[]' <<<"${user}")
    if [ "${#ssh_keys[@]}" -gt 0 ]; then
        home="$(getent passwd "${name}" | cut -d: -f6)"
        ssh_dir="${home}/.ssh"
        mkdir -p "${ssh_dir}"
        printf '%s\n' "${ssh_keys[@]}" >"${ssh_dir}/authorized_keys"
        chmod 700 "${ssh_dir}"
        chmod 600 "${ssh_dir}/authorized_keys"
        chown -R "${name}:" "${ssh_dir}"
        echo "Wrote ${#ssh_keys[@]} SSH key(s) for ${name}"
    fi
done
