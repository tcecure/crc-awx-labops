#!/usr/bin/env bash
# Baseline hardening + Docker for drcc-labops-01, per platform/labops-ai/docs/deployment-plan.md.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "== packages"
sudo -n apt-get update -qq
sudo -n apt-get install -y -qq \
  ca-certificates curl gnupg jq nftables fail2ban unattended-upgrades \
  qemu-guest-agent chrony openssl

echo "== docker engine (docker apt repo)"
if ! command -v docker >/dev/null 2>&1; then
  sudo -n install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo -n gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo -n chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    | sudo -n tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo -n apt-get update -qq
  sudo -n apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "== docker daemon config"
sudo -n mkdir -p /etc/docker
sudo -n tee /etc/docker/daemon.json >/dev/null <<'JSON'
{
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "log-driver": "json-file",
  "log-opts": { "max-size": "20m", "max-file": "5" },
  "default-address-pools": [ { "base": "172.31.0.0/16", "size": 24 } ]
}
JSON
sudo -n systemctl enable --now docker
sudo -n systemctl restart docker

echo "== service user and directories"
id labops-gateway >/dev/null 2>&1 || sudo -n useradd --system --create-home --home-dir /var/lib/labops-gateway --shell /usr/sbin/nologin labops-gateway
sudo -n mkdir -p /etc/labops /opt/labops /opt/labops/app/releases /opt/labops/app/shared /var/log/labops
sudo -n chown root:labops-gateway /etc/labops
sudo -n chmod 0750 /etc/labops
sudo -n chown -R labops-gateway:labops-gateway /opt/labops/app /var/log/labops

# Investigation containers run as uid 10001 under a read-only rootfs, so each per-run volume
# has to be writable by that uid: a root-owned volume makes every POST /api/conversations
# fail with "Permission denied: /home/openhands/.openhands/profiles".
# scripts/run-investigation.sh does this per run; nothing shared is pre-created here.

echo "== nftables: default-deny inbound, allow-listed egress"
# Destination sets live in a separate file so adding an integration is a reviewed one-liner.
# @model_egress is refreshed from DNS by labops-egress-refresh.timer and is empty-safe: a
# failed refresh denies model traffic rather than opening the ruleset.
sudo -n mkdir -p /etc/nftables.d
# keep the pre-Phase-2 ruleset as the documented rollback path (docs/phase2/13-rollback-plan.md)
if [ -f /etc/nftables.conf ] && ! [ -f /etc/nftables.conf.pre-phase2 ]; then
  sudo -n cp /etc/nftables.conf /etc/nftables.conf.pre-phase2
fi
if ! [ -f /etc/nftables.d/labops-sets.conf ]; then
  sudo -n tee /etc/nftables.d/labops-sets.conf >/dev/null <<'SETS'
# LabOps allow-listed destinations. Edit under review only.
define LAB_DNS      = { 192.168.1.1, 1.1.1.1, 8.8.8.8 }   # lab resolver + systemd-resolved upstreams
define LAB_SERVICES = { 192.168.1.103, 192.168.1.61, 192.168.1.42 }   # awx, tracker, wiki
SETS
fi
sudo -n tee /etc/nftables.conf >/dev/null <<'NFT'
#!/usr/sbin/nft -f
# drcc-labops-01. Inbound: SSH + gateway port from the lab management network only.
# Egress: default-deny in both the forward hook (containers) and the output hook (host),
# per docs/phase2/04-network-egress.md. Investigation containers sit on labops-model
# (172.31.241.0/24, docker internal: true) and have no forward rule at all; only the model
# proxy's outer leg (172.31.240.0/24) may leave the host, and only to the provider.
flush ruleset

include "/etc/nftables.d/labops-sets.conf"

table inet filter {
  set admin_net {
    type ipv4_addr; flags interval
    elements = { 192.168.1.0/24 }
  }

  set lab_dns      { type ipv4_addr; elements = $LAB_DNS }
  set lab_services { type ipv4_addr; elements = $LAB_SERVICES }

  # api.openai.com, refreshed by labops-egress-refresh.service
  set model_egress { type ipv4_addr; flags interval; }

  # supabase and the image/package registries the host itself needs
  set host_egress_names {
    type ipv4_addr; flags interval;
  }

  chain input {
    type filter hook input priority filter; policy drop;
    iif lo accept
    ct state established,related accept
    ip protocol icmp icmp type { echo-request, echo-reply, destination-unreachable, time-exceeded } accept
    tcp dport 22   ip saddr @admin_net accept
    tcp dport 3100 ip saddr @admin_net accept
    tcp dport 8000 drop comment "agent servers are never reachable from the wire"
    # investigation containers must not reach the gateway API on the bridge address either
    ip saddr 172.31.240.0/23 drop comment "no container may talk to host services"
    counter log prefix "labops-in-drop " level info
  }

  chain forward {
    type filter hook forward priority filter; policy drop;
    ct state established,related accept
    # investigation containers reach the model proxy and nothing else. Same-bridge container
    # traffic traverses this hook, so without this rule labops-model is dead, not isolated.
    ip saddr 172.31.241.0/24 ip daddr 172.31.241.2 tcp dport 8081 accept
    # model proxy outer leg only: DNS to the lab resolver and TLS to the provider
    ip saddr 172.31.240.0/24 udp dport 53  ip daddr @lab_dns      accept
    ip saddr 172.31.240.0/24 tcp dport 53  ip daddr @lab_dns      accept
    ip saddr 172.31.240.0/24 tcp dport 443 ip daddr @model_egress accept
    counter log prefix "labops-fwd-drop " level info
  }

  chain output {
    type filter hook output priority filter; policy drop;
    oif lo accept
    ct state established,related accept
    ip protocol icmp accept
    # the gateway drives investigation containers and the proxy over the docker bridges
    ip daddr 172.31.240.0/23 accept comment "host -> labops containers"
    udp dport 53 ip daddr @lab_dns accept
    tcp dport 53 ip daddr @lab_dns accept
    udp dport 123 accept comment "chrony"
    # Supabase, ghcr.io and the deb repos are name-based and resolved into @host_egress_names
    tcp dport 443 ip daddr @host_egress_names accept
    tcp dport { 80, 4000, 30080 } ip daddr @lab_services accept comment "awx, tracker, wiki"
    tcp dport 22 ip daddr @admin_net accept
    tcp dport { 25, 465, 587 } ip daddr @host_egress_names accept comment "notification smtp"
    counter log prefix "labops-out-drop " level info
  }
}
NFT

# Resolve the name-based egress allow-list into the nftables sets. A resolution failure leaves
# the previous elements in place and never opens up.
#
# The sets accumulate rather than being rewritten: api.openai.com and Supabase sit behind
# CDNs that answer with a rotating pool, so a flush-and-replace refresh drops the very
# connection that resolved a new address a second earlier. Elements are cleared once a day
# (stamp file) so a retired address does not stay allowed forever.
sudo -n tee /usr/local/sbin/labops-egress-refresh >/dev/null <<'REFRESH'
#!/usr/bin/env bash
set -uo pipefail
MODEL_HOSTS="api.openai.com"
HOST_HOSTS="kkacbtkacadgsnbylkti.supabase.co ghcr.io pkg-containers.githubusercontent.com \
  archive.ubuntu.com security.ubuntu.com download.docker.com email-smtp.us-east-1.amazonaws.com"
STAMP=/run/labops-egress-refresh.pruned
# Query each name several times: the CDNs in front of these hosts answer with a rotating
# subset of their address pool, and the container resolvers see answers the host has not.
resolve() { for i in 1 2 3 4 5; do for h in $1; do getent ahostsv4 "$h" | awk '{print $1}'; done; done | sort -u; }
add() { for a in $2; do nft add element inet filter "$1" "{ $a }" 2>/dev/null; done; }
model=$(resolve "$MODEL_HOSTS"); hosts=$(resolve "$HOST_HOSTS")
prune=0
if [ -n "$model" ] && [ -n "$hosts" ]; then
  if ! [ -f "$STAMP" ] || [ $(( $(date +%s) - $(stat -c %Y "$STAMP") )) -gt 86400 ]; then
    prune=1
  fi
fi
if [ "$prune" = 1 ]; then
  nft flush set inet filter model_egress
  nft flush set inet filter host_egress_names
  touch "$STAMP"
fi
[ -n "$model" ] && add model_egress "$model"
[ -n "$hosts" ] && add host_egress_names "$hosts"
REFRESH
sudo -n chmod 0755 /usr/local/sbin/labops-egress-refresh
sudo -n tee /etc/systemd/system/labops-egress-refresh.service >/dev/null <<'UNIT'
[Unit]
Description=Refresh LabOps allow-listed egress addresses
After=nftables.service network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/labops-egress-refresh
UNIT
sudo -n tee /etc/systemd/system/labops-egress-refresh.timer >/dev/null <<'UNIT'
[Unit]
Description=Refresh LabOps allow-listed egress addresses every 2 minutes
[Timer]
OnBootSec=30s
OnUnitActiveSec=2m
[Install]
WantedBy=timers.target
UNIT
sudo -n nft -c -f /etc/nftables.conf
sudo -n systemctl enable --now nftables
# 'flush ruleset' drops Docker's own chains; Docker rebuilds them when restarted, and
# without this container networking fails with "No chain/target/match by that name".
sudo -n mkdir -p /etc/systemd/system/nftables.service.d
sudo -n tee /etc/systemd/system/nftables.service.d/10-restart-docker.conf >/dev/null <<'DROPIN'
[Service]
ExecStartPost=-/bin/systemctl try-restart docker.service
DROPIN
sudo -n systemctl daemon-reload
sudo -n systemctl restart nftables
# The output chain is default-deny from here on, so resolve the allow-list before anything
# else on the host tries to reach Supabase or a registry.
sudo -n systemctl enable --now labops-egress-refresh.timer
sudo -n systemctl start labops-egress-refresh.service

echo "== unattended upgrades / time / guest agent"
sudo -n systemctl enable --now unattended-upgrades chrony qemu-guest-agent fail2ban

echo "== ssh: keys only"
sudo -n tee /etc/ssh/sshd_config.d/60-labops.conf >/dev/null <<'SSHD'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
SSHD
sudo -n systemctl reload ssh || sudo -n systemctl reload sshd

echo "== done"
docker --version
sudo -n nft list chain inet filter input | sed -n 1,20p
