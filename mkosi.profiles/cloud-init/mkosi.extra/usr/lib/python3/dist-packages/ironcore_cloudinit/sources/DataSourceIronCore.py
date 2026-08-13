# This file is part of the IronCore mkosi images, installed out-of-tree and
# registered via datasource_pkg_list (see /etc/cloud/cloud.cfg.d/).
#
# cloud-init datasource for the IronCore metaldata service. Fetches the
# metadata JSON document and maps it onto standard cloud-init data:
#
#   * user-data["cloud-init"] is used verbatim as cloud-init user-data
#     (any standard format: #cloud-config, #!, #include, MIME, ...).
#   * "server-name" becomes meta-data local-hostname.
#   * The instance-id is the DMI product UUID, falling back to
#     /etc/machine-id where DMI data is absent or bogus (VMs).
#
# The datasource declares a network dependency and therefore only runs in
# cloud-init's network boot stage, once systemd-networkd has brought up
# DHCP, like the metadata-service datasources of the larger clouds.
#
# The URL can be overridden for development/testing (e.g. to point at a
# mock service on a QEMU host) via cloud.cfg.d:
#
#   datasource:
#     IronCore:
#       metadata_url: "http://10.0.2.2:8080/v1/"

import json
import logging

from cloudinit import sources, url_helper, util

LOG = logging.getLogger(__name__)

METADATA_URL = "http://metaldata.ironcore.dev/v1/"
HEADERS = {"Metadata-Flavor": "IronCore Metal"}

# Well-known SMBIOS "no real UUID" values.
_BOGUS_UUIDS = frozenset(
    {
        "00000000-0000-0000-0000-000000000000",
        "ffffffff-ffff-ffff-ffff-ffffffffffff",
        "03000200-0400-0500-0006-000700080009",
    }
)


def _instance_id():
    uuid = ""
    try:
        with open("/sys/class/dmi/id/product_uuid", encoding="utf-8") as f:
            uuid = f.read().strip().lower()
    except OSError:
        pass
    if uuid and uuid not in _BOGUS_UUIDS:
        return uuid

    # Fallback: stable for the lifetime of an installation, regenerated on
    # reinstall, so re-provisioning re-runs first-boot modules.
    machine_id = ""
    try:
        with open("/etc/machine-id", encoding="utf-8") as f:
            machine_id = f.read().strip()
    except OSError:
        pass
    if machine_id and machine_id != "uninitialized":
        return machine_id

    # Last resort, mirrors the base class fallback.
    return "iid-ironcore"


class DataSourceIronCore(sources.DataSource):
    dsname = "IronCore"

    def _get_data(self):
        url = util.get_cfg_by_path(
            self.sys_cfg, ("datasource", "IronCore", "metadata_url"),
            METADATA_URL,
        )
        try:
            response = url_helper.readurl(
                url, headers=HEADERS, timeout=5, retries=3
            )
            doc = json.loads(response.contents.decode("utf-8"))
        except url_helper.UrlError as e:
            # metaldata unreachable (foreign platform, tests, ...).
            LOG.debug("metaldata not available: %s", e)
            return False
        except (ValueError, UnicodeDecodeError) as e:
            LOG.warning("invalid metaldata response: %s", e)
            return False

        userdata = (doc.get("user-data") or {}).get("cloud-init")
        if not isinstance(userdata, str) or not userdata:
            LOG.debug("no 'user-data.cloud-init' in metaldata, skipping")
            return False

        metadata = {"instance-id": _instance_id()}
        if doc.get("server-name"):
            metadata["local-hostname"] = str(doc["server-name"])

        self.metadata = metadata
        self.userdata_raw = userdata
        return True


_datasources = [
    (DataSourceIronCore, (sources.DEP_FILESYSTEM, sources.DEP_NETWORK)),
]


def get_datasource_list(depends):
    return sources.list_from_depends(depends, _datasources)
