## ironcore

Meant to be combined with `metal` since IronCore itself does not have generic
user-data support yet.

Custom user-data service similar to cloud-init and ignition. Works best in
combination with the IronCore metaldata service.

### User-Data Format

The metadata JSON (fetched from `http://metaldata.ironcore.dev/v1/`) contains a
top-level `user-data` object with the following optional fields:

#### `users`

Array of user objects. Each user is created (or updated if already existing)
at boot.

| Field           | Type       | Required | Description                                      |
|-----------------|------------|----------|--------------------------------------------------|
| `name`          | string     | yes      | Login name                                       |
| `groups`        | []string   | no       | Groups to add the user to (created if missing)   |
| `password_hash` | string     | no       | Hashed password (crypt(3) format)                |
| `ssh_keys`      | []string   | no       | Public SSH keys written to `~/.ssh/authorized_keys` |

Example:

```json
{
  "user-data": {
    "users": [
      {
        "name": "max",
        "groups": ["sudo", "docker"],
        "password_hash": "$6$rounds=4096$...",
        "ssh_keys": ["ssh-ed25519 AAAA... max@host"]
      }
    ]
  }
}
```

#### `files`

Array of file objects. Each file is written to disk at boot.

| Field     | Type   | Required | Default      | Description                          |
|-----------|--------|----------|--------------|--------------------------------------|
| `path`    | string | yes      |              | Absolute destination path            |
| `content` | string | yes      |              | File content (written verbatim)      |
| `owner`   | string | no       | `root:root`  | Owner and group (`user:group`)       |
| `mode`    | string | no       | `0644`       | File permissions (octal)             |

Example:

```json
{
  "user-data": {
    "files": [
      {
        "path": "/etc/motd",
        "content": "Welcome!\n",
        "owner": "root:root",
        "mode": "0644"
      }
    ]
  }
}
```

### Top-Level Metadata Fields

#### `server-name`

String. If present, the system hostname is set to this value via
`hostnamectl set-hostname`.
