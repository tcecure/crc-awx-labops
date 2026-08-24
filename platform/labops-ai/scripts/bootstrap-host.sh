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

echo "== nftables: default-deny inbound, allow-listed egress"
sudo -n tee /etc/nftables.conf >/dev/null <<'NFT'
#!/usr/sbin/nft -f
# drcc-labops-01. Inbound: SSH + gateway port from the lab management network only.
# The OpenHands agent server on 8000 is published to 127.0.0.1 only and is never
# permitted from the wire, regardless of this ruleset.
flush ruleset

table inet filter {
  set admin_net {
    type ipv4_addr; flags interval
    elements = { 192.168.1.0/24 }
  }

  chain input {
    type filter hook input priority filter; policy drop;
    iif lo accept
    ct state established,related accept
    ip protocol icmp icmp type { echo-request, echo-reply, destination-unreachable, time-exceeded } accept
    tcp dport 22   ip saddr @admin_net accept
    tcp dport 3100 ip saddr @admin_net accept
    tcp dport 8000 drop comment "agent server is loopback-only"
    counter log prefix "labops-in-drop " level info
  }

  chain forward {
    # Docker manages its own forward rules in the ip filter table; nothing extra here.
    type filter hook forward priority filter; policy accept;
  }

  chain output {
    type filter hook output priority filter; policy accept;
  }
}
NFT
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
