# Checkpoint 4 — Network egress correction

## The documentation/implementation discrepancy

`docs/deployment-plan.md` and `bootstrap-host.sh`'s own banner say "default-deny inbound,
allow-listed egress". Live state on `drcc-labops-01`:

```
chain input   { policy drop;   }   # correct
chain forward { policy accept; }   # every container can route anywhere
chain output  { policy accept; }   # host can reach anything
```

and `compose_labops-internal` is `internal: false`, so the agent container is NATed to the
lab network and the internet. Nothing about egress was ever enforced. The word
"allow-listed" is removed from the plan, and the ruleset below is what makes it true.

## Enforced topology

Fixed subnets so nftables can match without guessing bridge names:

| Docker network | Subnet | `internal` | Members |
| --- | --- | --- | --- |
| `labops-model` | `172.31.241.0/24` | **true** | investigation containers + model proxy (inner leg) |
| `labops-egress` | `172.31.240.0/24` | false | model proxy (outer leg) only |

`internal: true` means Docker installs no default route and no masquerade for
`labops-model`: an investigation container has no path off the host even before nftables.
The only address it can open a socket to is the proxy on `172.31.241.2:8081`.

## nftables (applied by `bootstrap-host.sh`)

```
chain forward {
  type filter hook forward priority filter; policy drop;
  ct state established,related accept
  ip saddr 172.31.240.0/24 udp dport 53 ip daddr @lab_dns accept
  ip saddr 172.31.240.0/24 tcp dport 443 ip daddr @model_egress accept
  counter log prefix "labops-fwd-drop " level info
}
chain output {
  type filter hook output priority filter; policy drop;
  oif lo accept
  ct state established,related accept
  udp dport 53 ip daddr @lab_dns accept
  udp dport 123 accept                       # chrony
  tcp dport 443 ip daddr @host_egress accept # supabase, ghcr, deb repos, api.openai.com
  tcp dport { 30080, 4000, 80 } ip saddr @self ip daddr @lab_services accept  # awx, tracker, wiki
  ip daddr 192.168.1.0/24 tcp dport 22 accept
  counter log prefix "labops-out-drop " level info
}
```

* `@model_egress` is refreshed from DNS for `api.openai.com` by
  `labops-egress-refresh.timer` (every 15 min, `nft flush set` + re-add); the set is empty-safe
  so a failed refresh denies rather than opens.
* `169.254.169.254` is unreachable by construction (no forward accept covers it, and the
  proxy's allow-list is host-name based) — the metadata check is in the test script anyway.
* Host `output` becoming default-deny is what stops the *gateway* being a confused deputy for
  anything not on the allow-list; the sets are in `/etc/nftables.d/labops-sets.conf` so a
  new integration is a reviewed one-line change.

## Required denials, and how each is proven

`scripts/test-egress-isolation.sh` runs each probe **inside a live investigation container**
(`docker exec`) and requires failure. Every probe uses a 5 s timeout so a drop looks like a
timeout, not a refusal:

| Target | Probe |
| --- | --- |
| public internet | `curl https://example.com/`, `curl http://1.1.1.1/`, `getent hosts github.com` |
| Supabase | `curl https://kkacbtkacadgsnbylkti.supabase.co/rest/v1/` |
| AWX | `curl http://192.168.1.103:30080/api/v2/ping/` |
| Wiki.js | `curl http://192.168.1.42/graphql` |
| Proxmox | `curl -k https://192.168.1.10:8006/api2/json/version` |
| Active Directory | `nc -z 192.168.1.20 389`, `nc -z 192.168.1.20 445` |
| student pods | `nc -z 10.51.6.1 22`, `nc -z 10.52.6.50 80` |
| gateway internal API | `curl http://172.31.241.1:3100/api/labops/health` and the host LAN IP |
| cloud metadata | `curl http://169.254.169.254/latest/meta-data/` |
| another internal host | `nc -z 192.168.1.51 4822` (Guacamole) |
| **allowed** | `curl $LABOPS_LLM_BASE_URL/models` → 200 through the proxy, provider key never visible |

The model proxy additionally refuses `CONNECT`, refuses any path outside `/v1/`, refuses any
upstream other than the configured provider, and strips client-supplied `Authorization`, so it
cannot be used as a general tunnel even by a terminal command that finds its address.
