#!/usr/bin/env python3
"""Auto-advance CMMC lab families per pod.

When a pod completes every lab in its current family, seed the *next* family
for that pod only (per-pod), so students progress at their own pace without
resetting completed work.

Signals used:
  * Completion  -> from each family's latest successful AWX verify job artifacts
                   (a family is "complete" only if all its labs are completed;
                   a family can only reach this state if it was seeded first,
                   so completion is a reliable, false-positive-free trigger).
  * Seeded      -> from per-family seed markers on DC01
                   (C:\\CyberLab\\PodNN\\.families\\<FAM>.seeded), collected by
                   the calling playbook and passed in as a JSON file. This is
                   what makes advancement idempotent: a family is never
                   re-seeded (which would reset progress) once its marker exists.

Guardrails:
  * Only advances when the current family is 100% complete.
  * Only seeds the next family if it is NOT already seeded (idempotent).
  * Advances at most one family per pod per run (the earliest gap).
  * ADVANCE_DRY_RUN=1 computes and prints decisions without launching seeds.
  * ADVANCE_ENABLED=0 disables all launching (report-only).

Environment:
  CRC_AWX_HOST     e.g. http://10.43.121.132  (AWX in-cluster ClusterIP; no /api/v2)
  CRC_AWX_TOKEN    AWX OAuth2 token (Bearer)
  ADVANCE_DRY_RUN  "1" to skip launches (default "0")
  ADVANCE_ENABLED  "0" to disable launches (default "1")
  SEED_MARKERS_FILE path to JSON list of marker file paths (default /tmp/seed_markers.json)
"""
import json
import os
import re
import ssl
import sys
import urllib.request
import urllib.error

FAMILY_ORDER = ["AC", "IA", "SI", "SC", "MP", "PE"]

VERIFY_TEMPLATES = {"AC": 13, "IA": 16, "SI": 19, "SC": 22, "MP": 26, "PE": 29}
SEED_TEMPLATES = {"AC": 12, "IA": 15, "SI": 18, "SC": 21, "MP": 25, "PE": 28}

LABS = {
    "AC": ["L1.1", "L1.2", "L1.3", "L2.1", "L2.2", "L2.3",
           "L3.1", "L3.2", "L3.3", "L4.1", "L4.2", "L4.3"],
    "IA": ["M1-L1", "M1-L2", "M1-L3", "M2-L1", "M2-L2", "M2-L3",
           "M3-L1", "M3-L2", "M3-L3", "M4-L1", "M4-L2", "M4-L3"],
    "SI": ["SI-M1-L1", "SI-M1-L2", "SI-M1-L3", "SI-M2-L1", "SI-M2-L2", "SI-M2-L3",
           "SI-M3-L1", "SI-M3-L2", "SI-M3-L3", "SI-M4-L1", "SI-M4-L2", "SI-M4-L3"],
    "SC": ["SC-M1-L1", "SC-M1-L2", "SC-M1-L3", "SC-M2-L1", "SC-M2-L2", "SC-M2-L3",
           "SC-M3-L1", "SC-M3-L2", "SC-M3-L3", "SC-M4-L1", "SC-M4-L2", "SC-M4-L3"],
    "MP": ["MP-M1-L1", "MP-M1-L2", "MP-M1-L3"],
    "PE": ["PE-M1-L1", "PE-M1-L2", "PE-M2-L1", "PE-M2-L2", "PE-M3-L1", "PE-M3-L2"],
}

MARKER_RE = re.compile(r"Pod0*(\d+)[\\/]\.families[\\/]([A-Z]{2})\.seeded$", re.IGNORECASE)


def _req(url, token, method="GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Authorization", "Bearer %s" % token)
    r.add_header("Content-Type", "application/json")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    with urllib.request.urlopen(r, context=ctx, timeout=45) as resp:
        raw = resp.read().decode()
        return resp.status, (json.loads(raw) if raw else {})


def latest_artifacts(host, token, template_id):
    """Return artifacts dict of the most recent successful verify job."""
    url = ("%s/api/v2/jobs/?job_template=%d&status=successful&order_by=-finished&page_size=1"
           % (host, template_id))
    _, data = _req(url, token)
    results = data.get("results", [])
    if not results:
        return {}
    job_id = results[0]["id"]
    _, detail = _req("%s/api/v2/jobs/%d/" % (host, job_id), token)
    return detail.get("artifacts") or {}


def family_completion(artifacts_by_family):
    """pod -> set of families that are 100% complete."""
    completed = {}
    for fam in FAMILY_ORDER:
        arts = artifacts_by_family.get(fam, {})
        for pod_key, labs in arts.items():
            if not isinstance(labs, dict):
                continue
            wanted = LABS[fam]
            done = all(isinstance(labs.get(l), dict) and labs[l].get("completed") for l in wanted)
            if done:
                completed.setdefault(pod_key, set()).add(fam)
    return completed


def parse_seed_markers(paths):
    """list of marker paths -> pod -> set of seeded families."""
    seeded = {}
    for p in paths:
        m = MARKER_RE.search(p.replace("/", "\\"))
        if m:
            pod_key = "pod%02d" % int(m.group(1))
            seeded.setdefault(pod_key, set()).add(m.group(2).upper())
    return seeded


def decide(completed, seeded):
    """Return list of (pod_key, next_family) advancement actions.

    For each pod, find the earliest family in order that is complete whose
    successor is not yet seeded; seed that successor. One step per pod per run.
    """
    actions = []
    pods = set(completed) | set(seeded)
    for pod_key in sorted(pods):
        comp = completed.get(pod_key, set())
        seed = seeded.get(pod_key, set())
        for idx in range(len(FAMILY_ORDER) - 1):
            fam = FAMILY_ORDER[idx]
            nxt = FAMILY_ORDER[idx + 1]
            if fam in comp and nxt not in seed:
                actions.append((pod_key, nxt))
                break
    return actions


def launch_seed(host, token, family, pod_num):
    tid = SEED_TEMPLATES[family]
    url = "%s/api/v2/job_templates/%d/launch/" % (host, tid)
    status, body = _req(url, token, method="POST",
                        body={"extra_vars": json.dumps({"pods": str(pod_num)})})
    return status, body.get("id") or body.get("job")


def main():
    host = (os.environ.get("CRC_AWX_HOST") or os.environ.get("AWX_HOST", "")).rstrip("/")
    token = os.environ.get("CRC_AWX_TOKEN") or os.environ.get("AWX_TOKEN", "")
    dry = os.environ.get("ADVANCE_DRY_RUN", "0") == "1"
    enabled = os.environ.get("ADVANCE_ENABLED", "1") == "1"
    markers_file = os.environ.get("SEED_MARKERS_FILE", "/tmp/seed_markers.json")
    if not host or not token:
        print("ERROR: AWX_HOST and AWX_TOKEN must be set", file=sys.stderr)
        return 2

    try:
        with open(markers_file) as f:
            marker_paths = json.load(f)
    except (OSError, ValueError):
        marker_paths = []

    artifacts_by_family = {fam: latest_artifacts(host, token, tid)
                           for fam, tid in VERIFY_TEMPLATES.items()}
    completed = family_completion(artifacts_by_family)
    seeded = parse_seed_markers(marker_paths)
    actions = decide(completed, seeded)

    print("=== Auto-Advance summary ===")
    print("completed families: %s"
          % {k: sorted(v) for k, v in sorted(completed.items())})
    print("seeded families:    %s"
          % {k: sorted(v) for k, v in sorted(seeded.items())})
    print("actions (%d): %s" % (len(actions), actions))
    print("dry_run=%s enabled=%s" % (dry, enabled))

    launched = []
    for pod_key, family in actions:
        pod_num = int(pod_key.replace("pod", ""))
        if dry or not enabled:
            print("  WOULD advance %s -> seed %s (pod %d)" % (pod_key, family, pod_num))
            continue
        status, job_id = launch_seed(host, token, family, pod_num)
        print("  ADVANCED %s -> seed %s (pod %d): http %s job %s"
              % (pod_key, family, pod_num, status, job_id))
        launched.append({"pod": pod_key, "family": family, "job": job_id})

    print("launched %d seed job(s)" % len(launched))
    return 0


if __name__ == "__main__":
    sys.exit(main())
