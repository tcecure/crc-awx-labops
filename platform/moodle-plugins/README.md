# Moodle plugins

## local_drccops — read-only activity reporting

`local_drccops` gives the DigitalRCC portal accurate recent-activity and
failed-login reporting for the admin-only Live Operations view. Moodle's standard
web services expose only `lastaccess` / `lastcourseaccess`, which is a coarse
last-seen timestamp and cannot answer "who is actually working right now" — and
the portal must never be pointed at the Moodle database directly.

The plugin therefore reads the standard log store and nothing else:

| Function | Purpose |
| --- | --- |
| `local_drccops_get_recent_events` | Standard log events after a cursor (`sinceid`) or timestamp, newest last, capped by `limit`. Web-service function calls are excluded by default so the portal's own polling never looks like student activity. |
| `local_drccops_get_failed_logins` | `\core\event\user_login_failed` records, including attempts against accounts that do not exist (Moodle records no user id for those). |

Both are declared `'type' => 'read'`. The plugin defines no write function, no
external page and no scheduled task.

### Capability

One capability, `local/drccops:viewactivity` (read, system context, allowed for
`manager` by archetype). The portal's `DigitalRCC Portal Read Only` system role
is granted this capability and nothing else new.

### Install / upgrade

```bash
./deploy-local-drccops.sh --dry-run   # prints the payload size, changes nothing
./deploy-local-drccops.sh
```

The LMS VM (192.168.1.169) is reachable only through `pve1`, so the plugin
travels as a base64 tarball over a nested ssh session; the remote step untars it
into `/var/www/moodle/local/drccops`, runs `admin/cli/upgrade.php
--non-interactive` and purges caches. Override `DRCC_LMS_JUMP`, `DRCC_LMS_HOST`
or `DRCC_MOODLE_ROOT` if the topology changes.

Then wire it up once, from the Moodle host (the script expects to sit beside
`config.php`, so copy it into the Moodle root first):

```bash
sudo -u www-data php /var/www/moodle/configure-local-drccops.php
```

It is idempotent. It adds both functions to the existing
`DigitalRCC Portal (read only)` external service and allows
`local/drccops:viewactivity` on the `DigitalRCC Portal Read Only` role, so the
existing token keeps working with no new credential.

### Rollback

1. Remove the two functions from the `DigitalRCC Portal (read only)` external
   service (Site administration → Server → Web services → External services →
   Functions). The portal stops reading activity immediately and Live Operations
   reports the connector as failed rather than showing an idle cohort.
2. Prohibit `local/drccops:viewactivity` on the portal role.
3. `rm -rf /var/www/moodle/local/drccops`, then visit
   `/admin/index.php` (or run `admin/cli/upgrade.php`) so Moodle uninstalls the
   plugin. No Moodle data is created or altered by the plugin, so nothing is left
   behind beyond its own config rows.
