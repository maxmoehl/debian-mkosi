#!/bin/bash
set -euo pipefail

mkdir -p /run/ironcore

curl -sf \
    -H "Metadata-Flavor: IronCore Metal" \
    -o /run/ironcore/metadata.json \
    http://metaldata.ironcore.dev/v1/
