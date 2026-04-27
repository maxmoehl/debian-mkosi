# users

Creates operator accounts with passwordless sudo and SSH key authentication.

Accounts are provisioned via `systemd-sysusers` and `systemd-tmpfiles`:

- `max` and `damyan` users, both in the `wheel` group
- SSH `authorized_keys` for each user
- `%wheel` granted `NOPASSWD` sudo
