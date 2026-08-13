#!/bin/sh
set -e

# Remove the ignition first-boot integration after it has run successfully.
# This runs as ignition-cleanup.service, ordered After=ignition-users.service
# ignition-files.service with Requires= on both, so it only fires when
# provisioning completed. On failure the services are left in place for
# debugging (and ConditionFirstBoot=yes means they won't re-run anyway).

# Disable the units (drops the Wants symlinks). Best-effort: some may already
# be mid-transaction, and disabling the currently-running cleanup service is
# fine — it's already loaded into memory.
systemctl disable \
    ignition-files.service \
    ignition-users.service \
    ignition-fetch.service \
    ignition-cleanup.service \
    ignition-bootstrap.target 2>/dev/null || true

# Remove the provisioning scripts, the boot-operator config, and the units.
rm -rf /usr/lib/ignition /etc/ignition
rm -f /usr/lib/systemd/system/ignition-*.service \
      /usr/lib/systemd/system/ignition-*.target
rm -rf /etc/systemd/system/ignition-bootstrap.target.wants 2>/dev/null || true

# Let systemd forget the removed units and clear any failed state.
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

echo "ignition first-boot integration removed"
