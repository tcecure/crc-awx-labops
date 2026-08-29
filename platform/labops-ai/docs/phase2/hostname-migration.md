# Hostname conflict — `labops.drcc.digitalrcc.com` vs `labops.digitalrcc.com`

## Current, authoritative state (unchanged by this sprint)

* Canonical URL: `https://labops.drcc.digitalrcc.com` — TLS certificate, `NEXT_PUBLIC_APP_URL`,
  `LABOPS_PUBLIC_URL`, Supabase auth redirect allow-list, cookie domain and every document all
  agree on this name.
* Namecheap A record `labops.drcc` → `108.31.169.90`; edge proxy `192.168.1.55` (VMID 101)
  forwards to the guest `192.168.1.65:3100`.
* VM hostname stays `drcc-labops-01`.

The earlier planning documents said `labops.digitalrcc.com`. That name was never provisioned.
Nothing in this sprint changes DNS, TLS, redirects, cookies or canonical URLs.

## If the shorter name is wanted later — no-downtime plan

1. **Add, do not move.** Create `labops.digitalrcc.com` A → `108.31.169.90` and issue a second
   certificate (or a SAN covering both). Keep the existing record untouched.
2. **Accept both at the edge.** Add the new `server_name` to the proxy vhost so both names serve
   the app. At this point the new name works and the old one is unaffected.
3. **Auth first.** Add the new origin to Supabase's redirect allow-list *before* announcing it,
   or logins on the new name will bounce.
4. **Flip the canonical values.** Set `NEXT_PUBLIC_APP_URL` / `LABOPS_PUBLIC_URL` to the new
   name and rebuild the release — `NEXT_PUBLIC_*` is inlined at build time, so a restart alone
   is not enough. Deploy as a new release directory and switch the symlink; roll back by
   switching it back.
5. **Then redirect.** Only once the new name has served authenticated traffic for a week, make
   the old vhost issue `301` to the new one. Keep the old DNS record and certificate for at
   least 90 days.
6. **Cookies.** Sessions are host-scoped; users are logged out once on the switch. Announce it,
   or set the cookie domain to `.digitalrcc.com` one release *before* the flip if that matters.
7. **Sweep the references.** `platform/labops-ai/**`, the nginx vhost, the systemd unit, the
   verification script, Wiki.js pages and the student guides all name the host explicitly.

Estimated effort: one working session, plus the deliberate one-week soak between steps 4 and 5.
