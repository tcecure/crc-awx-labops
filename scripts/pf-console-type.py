#!/usr/bin/env python3
"""Type a string into a pod gateway's console via qm sendkey.

Used to recover a pfSense firewall that has no reachable network path; pair it
with pf-console-shot.sh to read the console back.

usage: pf-console-type.py <vmid> <text> [ssh-host]
"""
import subprocess
import sys

SHIFT = {
    '!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7',
    '*': '8', '(': '9', ')': '0', '_': 'minus', '+': 'equal', '{': 'bracket_left',
    '}': 'bracket_right', '|': 'backslash', ':': 'semicolon', '"': 'apostrophe',
    '<': 'comma', '>': 'dot', '?': 'slash', '~': 'grave_accent',
}
PLAIN = {
    ' ': 'spc', '-': 'minus', '=': 'equal', '[': 'bracket_left', ']': 'bracket_right',
    '\\': 'backslash', ';': 'semicolon', "'": 'apostrophe', ',': 'comma', '.': 'dot',
    '/': 'slash', '`': 'grave_accent', '\n': 'ret',
}


def keys_for(text):
    out = []
    for ch in text:
        if ch.isalpha():
            out.append(('shift-' + ch.lower()) if ch.isupper() else ch)
        elif ch.isdigit():
            out.append(ch)
        elif ch in SHIFT:
            out.append('shift-' + SHIFT[ch])
        elif ch in PLAIN:
            out.append(PLAIN[ch])
        else:
            raise ValueError('unmapped char %r' % ch)
    return out


def main():
    vmid = sys.argv[1]
    text = sys.argv[2]
    host = sys.argv[3] if len(sys.argv) > 3 else 'pve1'
    keys = keys_for(text)
    script = '\n'.join('qm sendkey %s %s' % (vmid, k) for k in keys)
    subprocess.run(
        ['ssh', host, 'sudo bash -s'],
        input=script.encode(),
        check=True,
    )


if __name__ == '__main__':
    main()
