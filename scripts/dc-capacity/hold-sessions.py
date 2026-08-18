"""Open one RDP session through guacd, hold it, and report whether it stuck.

Used to prove a shared session host really accepts a cohort's worth of
concurrent sessions (see docs/runbooks/SHARED-DC-CAPACITY.md). Run one process
per student, in parallel, from a host that can reach guacd, then confirm with
`quser` on the target that all of the sessions are logged on at the same time.

    python3 hold-sessions.py <guacd-host> <target> <netbios-domain> \
        <username> <password> <hold-seconds>

Prints a JSON line whose "status" is "established" when the session came up.
Log the sessions off on the target afterwards.
"""
import json
import socket
import sys
import time

HOST = sys.argv[1]
PORT = 4822
TARGET = sys.argv[2]
DOMAIN = sys.argv[3]
USER = sys.argv[4]
PASSWORD = sys.argv[5]
HOLD = int(sys.argv[6])

params = {
    "hostname": TARGET,
    "port": "3389",
    "domain": DOMAIN,
    "username": USER,
    "password": PASSWORD,
    "security": "nla",
    "ignore-cert": "true",
    "width": "1024",
    "height": "768",
    "dpi": "96",
}


def inst(*vals):
    return ",".join("%d.%s" % (len(v), v) for v in vals) + ";"


buf = ""


def read_inst(sock):
    global buf
    while ";" not in buf:
        data = sock.recv(65536)
        if not data:
            return None
        buf += data.decode("utf-8", "replace")
    i = buf.index(";")
    raw, buf = buf[:i], buf[i + 1:]
    parts = []
    while raw:
        dot = raw.index(".")
        n = int(raw[:dot])
        parts.append(raw[dot + 1:dot + 1 + n])
        raw = raw[dot + 1 + n:].lstrip(",")
    return parts


def main():
    result = {"user": USER, "status": "unknown", "detail": ""}
    sock = socket.create_connection((HOST, PORT), 15)
    sock.sendall(inst("select", "rdp").encode())
    args = read_inst(sock)
    if not args or args[0] != "args":
        result["status"] = "handshake-failed"
        print(json.dumps(result))
        return
    names = args[1:]
    sock.sendall(inst("size", "1024", "768", "96").encode())
    sock.sendall(inst("audio", "").encode())
    sock.sendall(inst("video", "").encode())
    sock.sendall(inst("image", "").encode())
    sock.sendall(inst("connect", *[params.get(n, "") for n in names]).encode())

    sock.settimeout(HOLD + 60)
    established = False
    start = time.time()
    try:
        while True:
            parts = read_inst(sock)
            if parts is None:
                result["status"] = "established-then-closed" if established else "closed"
                break
            if parts[0] == "sync":
                if not established:
                    established = True
                    result["status"] = "established"
                sock.sendall(inst("sync", parts[1]).encode())
                if time.time() - start > HOLD:
                    result["detail"] = "held %ds" % HOLD
                    break
            elif parts[0] in ("error", "disconnect"):
                if not established:
                    result["status"] = "rejected"
                result["detail"] = " ".join(parts[:3])
                break
    except socket.timeout:
        result["detail"] = "timeout"
    print(json.dumps(result))


main()
