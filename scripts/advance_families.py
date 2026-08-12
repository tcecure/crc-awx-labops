#!/usr/bin/env python3
"""Auto-advance CMMC lab families and issue final completion certificates.

Completion comes from each family's latest successful AWX verifier. Seed markers
make family advancement idempotent. A student profile and FINAL issuance marker
make the single CMMC Level 1 certificate student-named and idempotent.

Environment:
  CRC_AWX_HOST         AWX URL without /api/v2
  CRC_AWX_TOKEN        AWX OAuth2 bearer token
  ADVANCE_DRY_RUN      "1" to report without launching anything
  ADVANCE_ENABLED      "0" to disable seed launches
  CERTIFICATES_ENABLED "1" to enable certificate launches (default "0")
  FAMILY_STATE_FILE    JSON list of seed, certificate, and profile paths
"""

import json
import os
import re
import ssl
import sys
import urllib.parse
import urllib.request

FAMILY_ORDER = ["AC", "IA", "SI", "SC", "MP", "PE"]
VERIFY_TEMPLATES = {"AC": 13, "IA": 16, "SI": 19, "SC": 22, "MP": 28, "PE": 31}
SEED_TEMPLATES = {"AC": 12, "IA": 15, "SI": 18, "SC": 21, "MP": 27, "PE": 30}
CERTIFICATE_TEMPLATE_NAME = "Generate Completion Certificate"

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

SEED_MARKER_RE = re.compile(
    r"Pod0*(\d+)[\\/]\.families[\\/]([A-Z]{2})\.seeded$", re.IGNORECASE
)
ISSUED_MARKER_RE = re.compile(
    r"Pod0*(\d+)[\\/]\.certificates[\\/](FINAL)\.issued$", re.IGNORECASE
)
PROFILE_RE = re.compile(
    r"Pod0*(\d+)[\\/]Certificates[\\/]CertificateProfile\.json$", re.IGNORECASE
)


def _req(url, token, method="GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("Authorization", "Bearer %s" % token)
    request.add_header("Content-Type", "application/json")
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    with urllib.request.urlopen(request, context=context, timeout=45) as response:
        raw = response.read().decode()
        return response.status, json.loads(raw) if raw else {}


def latest_verification(host, token, template_id):
    """Return (job_id, artifacts) from the latest successful verify job."""
    url = "%s/api/v2/jobs/?job_template=%d&status=successful&order_by=-finished&page_size=1" % (
        host, template_id
    )
    _, data = _req(url, token)
    results = data.get("results", [])
    if not results:
        return None, {}
    job_id = int(results[0]["id"])
    _, detail = _req("%s/api/v2/jobs/%d/" % (host, job_id), token)
    return job_id, detail.get("artifacts") or {}


def family_completion(artifacts_by_family):
    """Return pod -> set of families that are 100% complete."""
    completed = {}
    for family in FAMILY_ORDER:
        artifacts = artifacts_by_family.get(family, {})
        for pod_key, labs in artifacts.items():
            if not isinstance(labs, dict):
                continue
            done = all(
                isinstance(labs.get(lab), dict) and labs[lab].get("completed")
                for lab in LABS[family]
            )
            if done:
                completed.setdefault(pod_key, set()).add(family)
    return completed


def parse_family_state(paths):
    """Return seeded families, issued certificates, and pods with profiles."""
    seeded = {}
    issued = {}
    profiles = set()
    for path in paths:
        normalized = path.replace("/", "\\")
        match = SEED_MARKER_RE.search(normalized)
        if match:
            pod_key = "pod%02d" % int(match.group(1))
            seeded.setdefault(pod_key, set()).add(match.group(2).upper())
            continue
        match = ISSUED_MARKER_RE.search(normalized)
        if match:
            pod_key = "pod%02d" % int(match.group(1))
            issued.setdefault(pod_key, set()).add(match.group(2).upper())
            continue
        match = PROFILE_RE.search(normalized)
        if match:
            profiles.add("pod%02d" % int(match.group(1)))
    return seeded, issued, profiles


def decide_advancement(completed, seeded):
    """Return one earliest (pod, next family) seed action per pod."""
    actions = []
    pods = set(completed) | set(seeded)
    for pod_key in sorted(pods):
        complete = completed.get(pod_key, set())
        seed_state = seeded.get(pod_key, set())
        for index in range(len(FAMILY_ORDER) - 1):
            family = FAMILY_ORDER[index]
            next_family = FAMILY_ORDER[index + 1]
            if family in complete and next_family not in seed_state:
                actions.append((pod_key, next_family))
                break
    return actions


def decide_certificates(completed, issued, profiles, verification_jobs):
    """Return final-certificate actions and student-name-pending awards."""
    actions = []
    pending_names = []
    for pod_key in sorted(completed):
        complete = completed.get(pod_key, set())
        issued_state = issued.get(pod_key, set())
        if not set(FAMILY_ORDER).issubset(complete) or "FINAL" in issued_state:
            continue
        if pod_key in profiles:
            actions.append((pod_key, "FINAL", {
                family: verification_jobs[family] for family in FAMILY_ORDER
            }))
        else:
            pending_names.append((pod_key, "FINAL"))
    return actions, pending_names


def launch_seed(host, token, family, pod_num):
    template_id = SEED_TEMPLATES[family]
    url = "%s/api/v2/job_templates/%d/launch/" % (host, template_id)
    status, body = _req(
        url, token, method="POST", body={"extra_vars": json.dumps({"pods": str(pod_num)})}
    )
    return status, body.get("id") or body.get("job")


def find_job_template(host, token, name):
    query = urllib.parse.urlencode({"name": name, "page_size": 1})
    _, body = _req("%s/api/v2/job_templates/?%s" % (host, query), token)
    results = body.get("results", [])
    return int(results[0]["id"]) if results else None


def launch_certificate(host, token, template_id, pod_num, scope, verification_jobs):
    extra_vars = {
        "pod_id": pod_num,
        "certificate_scope": scope,
        "certificate_verification_jobs": verification_jobs,
    }
    url = "%s/api/v2/job_templates/%d/launch/" % (host, template_id)
    status, body = _req(
        url, token, method="POST", body={"extra_vars": json.dumps(extra_vars)}
    )
    return status, body.get("id") or body.get("job")


def main():
    host = (os.environ.get("CRC_AWX_HOST") or os.environ.get("AWX_HOST", "")).rstrip("/")
    token = os.environ.get("CRC_AWX_TOKEN") or os.environ.get("AWX_TOKEN", "")
    dry_run = os.environ.get("ADVANCE_DRY_RUN", "0") == "1"
    advance_enabled = os.environ.get("ADVANCE_ENABLED", "1") == "1"
    certificates_enabled = os.environ.get("CERTIFICATES_ENABLED", "0") == "1"
    state_file = os.environ.get("FAMILY_STATE_FILE", "/tmp/family_state_paths.json")
    if not host or not token:
        print("ERROR: CRC_AWX_HOST and CRC_AWX_TOKEN must be set", file=sys.stderr)
        return 2

    try:
        with open(state_file) as handle:
            state_paths = json.load(handle)
    except (OSError, ValueError):
        state_paths = []

    artifacts_by_family = {}
    verification_jobs = {}
    for family, template_id in VERIFY_TEMPLATES.items():
        job_id, artifacts = latest_verification(host, token, template_id)
        artifacts_by_family[family] = artifacts
        verification_jobs[family] = job_id

    completed = family_completion(artifacts_by_family)
    seeded, issued, profiles = parse_family_state(state_paths)
    advancement_actions = decide_advancement(completed, seeded)
    certificate_actions, pending_names = decide_certificates(
        completed, issued, profiles, verification_jobs
    )

    print("=== Auto-Advance and Certificates summary ===")
    print("completed families:   %s" % {k: sorted(v) for k, v in sorted(completed.items())})
    print("seeded families:      %s" % {k: sorted(v) for k, v in sorted(seeded.items())})
    print("issued certificates:  %s" % {k: sorted(v) for k, v in sorted(issued.items())})
    print("certificate profiles: %s" % sorted(profiles))
    print("seed actions (%d): %s" % (len(advancement_actions), advancement_actions))
    print("certificate actions (%d): %s" % (
        len(certificate_actions), [(pod, scope) for pod, scope, _ in certificate_actions]
    ))
    print("certificates pending student name (%d): %s" % (len(pending_names), pending_names))
    print("dry_run=%s advance_enabled=%s certificates_enabled=%s" % (
        dry_run, advance_enabled, certificates_enabled
    ))

    launched_seeds = []
    for pod_key, family in advancement_actions:
        pod_num = int(pod_key.replace("pod", ""))
        if dry_run or not advance_enabled:
            print("  WOULD advance %s -> seed %s (pod %d)" % (pod_key, family, pod_num))
            continue
        status, job_id = launch_seed(host, token, family, pod_num)
        print("  ADVANCED %s -> seed %s (pod %d): http %s job %s" % (
            pod_key, family, pod_num, status, job_id
        ))
        launched_seeds.append({"pod": pod_key, "family": family, "job": job_id})

    launched_certificates = []
    certificate_template_id = None
    if certificate_actions and certificates_enabled and not dry_run:
        certificate_template_id = find_job_template(host, token, CERTIFICATE_TEMPLATE_NAME)
        if not certificate_template_id:
            print("ERROR: AWX template '%s' was not found" % CERTIFICATE_TEMPLATE_NAME, file=sys.stderr)
            return 3

    for pod_key, scope, job_ids in certificate_actions:
        pod_num = int(pod_key.replace("pod", ""))
        if dry_run or not certificates_enabled:
            print("  WOULD issue %s certificate for %s" % (scope, pod_key))
            continue
        status, job_id = launch_certificate(
            host, token, certificate_template_id, pod_num, scope, job_ids
        )
        print("  ISSUED request for %s certificate to %s: http %s job %s" % (
            scope, pod_key, status, job_id
        ))
        launched_certificates.append({"pod": pod_key, "scope": scope, "job": job_id})

    print("launched %d seed job(s)" % len(launched_seeds))
    print("launched %d certificate job(s)" % len(launched_certificates))
    return 0


if __name__ == "__main__":
    sys.exit(main())
