#!/bin/bash
set -euo pipefail

CONFIG="/run/ignition/config.ign"

if [ ! -s "${CONFIG}" ]; then
    echo "No ignition config, nothing to do"
    exit 0
fi

files_raw="$(jq -r '.storage.files // empty' "${CONFIG}")"
if [ -z "${files_raw}" ]; then
    echo "No files in ignition config, nothing to do"
    exit 0
fi

fetch_source() {
    # ignition "data:" URL source. Returns the decoded payload on stdout.
    # Handles the standard forms:
    #   data:,<urlencoded>          (media type omitted)
    #   data:;base64,<payload>      (base64, no media type — the common form)
    #   data:text/plain;base64,<payload>  (base64 with media type)
    #   data:base64,<payload>       (non-strict base64, kept for completeness)
    local source="$1"
    case "${source}" in
        data:base64,*)
            base64 -d <<<"${source#data:base64,}"
            ;;
        data:*base64,*)
            # Strip everything up to and including the last "base64,".
            base64 -d <<<"${source##*base64,}"
            ;;
        data:,*)
            # urlencoded: + -> space, %XX -> bytes.
            local payload="${source#data:,}"
            payload="${payload//+/ }"
            printf '%b' "${payload//%/\\x}"
            ;;
        *)
            echo "error: unsupported file source: ${source}" >&2
            return 1
            ;;
    esac
}

echo "${files_raw}" | jq -c '.[]' | while IFS= read -r entry; do
    path="$(jq -r '.path' <<<"${entry}")"
    owner="$(jq -r '.user.name // empty' <<<"${entry}")"
    group="$(jq -r '.group.name // empty' <<<"${entry}")"
    overwrite="$(jq -r '.overwrite // false' <<<"${entry}")"

    # Ignition's mode is a *decimal* integer (e.g. 420 == 0o644). chmod reads
    # its argument as octal, so convert decimal -> octal (dropping any leading
    # zero from the octal form, which chmod would otherwise misread). A mode
    # given as an octal string (e.g. "0644") is passed through unchanged.
    mode="$(jq -r '.mode // empty' <<<"${entry}")"
    if [ -n "${mode}" ]; then
        case "${mode}" in
            ''|*[!0-9]*) ;;                      # non-numeric / octal string -> as-is
            *) mode="$(printf '%o' "${mode}")" ;; # decimal int -> octal
        esac
    fi

    # Resolve contents: prefer inline, fall back to source (data: URL).
    content="$(jq -r '.contents.inline // empty' <<<"${entry}")"
    if [ -z "${content}" ]; then
        source="$(jq -r '.contents.source // empty' <<<"${entry}")"
        if [ -n "${source}" ]; then
            content="$(fetch_source "${source}")"
        fi
    fi

    if [ -e "${path}" ] && [ "${overwrite}" != "true" ]; then
        echo "Skipping existing ${path} (overwrite not set)"
        continue
    fi

    mkdir -p "$(dirname "${path}")"
    printf '%s' "${content}" >"${path}"

    if [ -n "${mode}" ]; then
        chmod "${mode}" "${path}"
    fi
    if [ -n "${owner}" ] && [ -n "${group}" ]; then
        chown "${owner}:${group}" "${path}"
    elif [ -n "${owner}" ]; then
        chown "${owner}" "${path}"
    fi

    echo "Wrote ${path} (mode=${mode:-default}, owner=${owner:-default}:${group:-default})"
done
