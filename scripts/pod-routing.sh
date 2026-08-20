#!/bin/bash
# Routes each pod's server network (10.50.X.0/24) to that pod's pfSense LAN
# (10.51.X.0/24) on the matching interface only, so pods stay isolated from
# each other. Shared DC01 (10.50.1.10) reaches every pod's firewall UI because
# all students share that host.
set -u

IFACES=(ens19 ens20 ens21 ens22 ens23 enp2s1 enp2s2 enp2s3 enp2s4 enp2s5 \
        enp2s6 enp2s7 enp2s8 enp2s9 enp2s10 enp2s11 enp2s12 enp2s13 enp2s14 enp2s15)

sysctl -qw net.ipv4.ip_forward=1

for i in $(seq 1 20); do
  dev="${IFACES[$((i-1))]}"
  ip link show "$dev" >/dev/null 2>&1 || { echo "pod$i: $dev missing, skipped"; continue; }

  ip addr show dev "$dev" | grep -q "10.51.$i.2/24" || \
    ip addr add "10.51.$i.2/24" dev "$dev"

  iptables -t nat -C POSTROUTING -d "10.51.$i.0/24" -o "$dev" -j SNAT --to-source "10.51.$i.2" 2>/dev/null || \
    iptables -t nat -A POSTROUTING -d "10.51.$i.0/24" -o "$dev" -j SNAT --to-source "10.51.$i.2"

  for rule in "-s 10.50.$i.0/24 -d 10.51.$i.0/24 -i $dev -o $dev -j ACCEPT" \
              "-s 10.51.$i.0/24 -d 10.50.$i.0/24 -i $dev -o $dev -j ACCEPT" \
              "-s 10.50.1.10/32 -d 10.51.$i.0/24 -o $dev -j ACCEPT" \
              "-s 10.51.$i.0/24 -d 10.50.1.10/32 -i $dev -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"; do
    iptables -C DOCKER-USER $rule 2>/dev/null || iptables -I DOCKER-USER 1 $rule
  done
done

echo "pod routing applied"
