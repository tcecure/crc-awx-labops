#!/usr/bin/env python3
"""Generate validated DRCC Cyber Lab completion certificates and receipts."""

import argparse
import datetime as dt
import hashlib
import json
import os
import ssl
import sys
import urllib.request
from pathlib import Path

FAMILY_ORDER = ["AC", "IA", "SI", "SC", "MP", "PE"]
FAMILY_NAMES = {
    "AC": "Access Control",
    "IA": "Identification and Authentication",
    "SI": "System and Information Integrity",
    "SC": "System and Communications Protection",
    "MP": "Media Protection",
    "PE": "Physical Protection",
    "FINAL": "CMMC Level 1 Cyber Lab",
}
VERIFY_TEMPLATES = {"AC": 13, "IA": 16, "SI": 19, "SC": 22, "MP": 28, "PE": 31}
LABS = {
    "AC": ["L1.1", "L1.2", "L1.3", "L2.1", "L2.2", "L2.3", "L3.1", "L3.2", "L3.3", "L4.1", "L4.2", "L4.3"],
    "IA": ["M1-L1", "M1-L2", "M1-L3", "M2-L1", "M2-L2", "M2-L3", "M3-L1", "M3-L2", "M3-L3", "M4-L1", "M4-L2", "M4-L3"],
    "SI": ["SI-M1-L1", "SI-M1-L2", "SI-M1-L3", "SI-M2-L1", "SI-M2-L2", "SI-M2-L3", "SI-M3-L1", "SI-M3-L2", "SI-M3-L3", "SI-M4-L1", "SI-M4-L2", "SI-M4-L3"],
    "SC": ["SC-M1-L1", "SC-M1-L2", "SC-M1-L3", "SC-M2-L1", "SC-M2-L2", "SC-M2-L3", "SC-M3-L1", "SC-M3-L2", "SC-M3-L3", "SC-M4-L1", "SC-M4-L2", "SC-M4-L3"],
    "MP": ["MP-M1-L1", "MP-M1-L2", "MP-M1-L3"],
    "PE": ["PE-M1-L1", "PE-M1-L2", "PE-M2-L1", "PE-M2-L2", "PE-M3-L1", "PE-M3-L2"],
}


def request_json(url, token):
    request = urllib.request.Request(url)
    request.add_header("Authorization", "Bearer %s" % token)
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    with urllib.request.urlopen(request, context=context, timeout=45) as response:
        return json.loads(response.read().decode())


def verify_completion(host, token, pod_key, scope, verification_jobs):
    families = FAMILY_ORDER if scope == "FINAL" else [scope]
    completed_at = []
    validated_jobs = {}
    for family in families:
        job_id = int(verification_jobs.get(family, 0))
        if not job_id:
            raise ValueError("missing verification job ID for %s" % family)
        detail = request_json("%s/api/v2/jobs/%d/" % (host.rstrip("/"), job_id), token)
        if detail.get("status") != "successful":
            raise ValueError("AWX job %d is not successful" % job_id)
        if int(detail.get("job_template") or 0) != VERIFY_TEMPLATES[family]:
            raise ValueError("AWX job %d is not the %s verifier" % (job_id, family))
        pod_results = (detail.get("artifacts") or {}).get(pod_key)
        if not isinstance(pod_results, dict):
            raise ValueError("AWX job %d has no results for %s" % (job_id, pod_key))
        incomplete = [
            lab for lab in LABS[family]
            if not isinstance(pod_results.get(lab), dict) or not pod_results[lab].get("completed")
        ]
        if incomplete:
            raise ValueError("%s is not complete for %s: %s" % (family, pod_key, ", ".join(incomplete)))
        validated_jobs[family] = job_id
        if detail.get("finished"):
            completed_at.append(detail["finished"])
    return validated_jobs, max(completed_at) if completed_at else dt.datetime.now(dt.timezone.utc).isoformat()


def pdf_escape(value):
    return value.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def text_command(text, x, y, size, font="F1", color="0.12 0.18 0.25"):
    encoded = pdf_escape(text).encode("cp1252", errors="replace")
    return b"BT /%s %.1f Tf %s rg %.1f %.1f Td (" % (
        font.encode(), size, color.encode(), x, y
    ) + encoded + b") Tj ET\n"


def centered_text(text, y, size, font="F1", color="0.12 0.18 0.25"):
    width = len(text.encode("cp1252", errors="replace")) * size * 0.50
    return text_command(text, max(36, (792 - width) / 2), y, size, font, color)


def make_pdf(path, receipt):
    scope = receipt["scope"]
    family_name = receipt["award_name"]
    completion_date = receipt["completed_at"][:10]
    if scope == "FINAL":
        subtitle = "All six CMMC Level 1 families - 57 competency labs"
        award_line = "has successfully completed the full"
    else:
        subtitle = "%d competency labs independently verified" % len(receipt["labs"])
        award_line = "has successfully completed the CMMC Level 1 family"

    stream = bytearray()
    stream += b"0.05 0.22 0.31 rg 0 0 792 612 re f\n"
    stream += b"0.96 0.94 0.87 rg 18 18 756 576 re f\n"
    stream += b"0.11 0.36 0.46 RG 3 w 30 30 732 552 re S\n"
    stream += b"0.78 0.58 0.20 RG 1.5 w 39 39 714 534 re S\n"
    stream += centered_text("DIGITAL RESILIENCE COMMUNITY CLINIC", 535, 13, "F2", "0.11 0.36 0.46")
    stream += centered_text("CERTIFICATE OF COMPLETION", 468, 30, "F4", "0.05 0.22 0.31")
    stream += centered_text("This certifies that", 421, 14, "F3", "0.30 0.31 0.31")
    name_size = min(30, max(11, 470 / max(1, len(receipt["student_name"]) * 0.50)))
    stream += centered_text(receipt["student_name"], 365, name_size, "F4", "0.11 0.36 0.46")
    stream += b"0.78 0.58 0.20 RG 1 w 150 350 m 642 350 l S\n"
    stream += centered_text(award_line, 317, 14, "F3", "0.30 0.31 0.31")
    stream += centered_text(family_name, 271, 23, "F4", "0.05 0.22 0.31")
    stream += centered_text(subtitle, 234, 12, "F1", "0.30 0.31 0.31")
    stream += centered_text("Completed %s" % completion_date, 194, 12, "F2", "0.11 0.36 0.46")
    stream += text_command("Student account: %s" % receipt["student_account"], 70, 130, 9, "F1", "0.30 0.31 0.31")
    stream += text_command("Assigned pod: %s" % receipt["pod"], 70, 114, 9, "F1", "0.30 0.31 0.31")
    stream += text_command("Certificate ID: %s" % receipt["certificate_id"], 70, 88, 8, "F1", "0.30 0.31 0.31")
    stream += text_command("Receipt SHA-256: %s" % receipt["receipt_sha256"], 70, 72, 6.8, "F1", "0.30 0.31 0.31")
    stream += text_command("Automated competency verification recorded in the accompanying JSON receipt.", 416, 120, 8, "F3", "0.30 0.31 0.31")
    stream += text_command("Recipient name supplied by the student; completion verified by AWX.", 416, 102, 8, "F3", "0.30 0.31 0.31")

    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 792 612] /Resources << /Font << /F1 5 0 R /F2 6 0 R /F3 7 0 R /F4 8 0 R >> >> /Contents 4 0 R >>",
        b"<< /Length %d >>\nstream\n" % len(stream) + bytes(stream) + b"endstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Times-Italic >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Times-Bold >>",
    ]
    pdf = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for index, obj in enumerate(objects, 1):
        offsets.append(len(pdf))
        pdf += b"%d 0 obj\n" % index + obj + b"\nendobj\n"
    xref = len(pdf)
    pdf += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    for offset in offsets[1:]:
        pdf += b"%010d 00000 n \n" % offset
    pdf += b"trailer << /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objects) + 1, xref)
    path.write_bytes(pdf)


def build_receipt(args, verified_jobs, completed_at):
    pod = "Pod%02d" % args.pod_id
    families = FAMILY_ORDER if args.scope == "FINAL" else [args.scope]
    labs = [lab for family in families for lab in LABS[family]]
    issued_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    core = {
        "schema_version": 1,
        "issuer": "Digital Resilience Community Clinic",
        "program": "DRCC CMMC Level 1 Cyber Lab",
        "scope": args.scope,
        "award_name": FAMILY_NAMES[args.scope],
        "families": families,
        "labs": labs,
        "student_name": args.student_name.strip(),
        "student_account": args.student_account.strip(),
        "name_source": "student_supplied",
        "pod": pod,
        "completed_at": completed_at,
        "issued_at": issued_at,
        "verification_jobs": verified_jobs,
    }
    identity = json.dumps(core, sort_keys=True, separators=(",", ":")).encode()
    certificate_id = "DRCC-%s-P%02d-%s" % (
        args.scope, args.pod_id, hashlib.sha256(identity).hexdigest()[:12].upper()
    )
    core["certificate_id"] = certificate_id
    receipt_payload = json.dumps(core, sort_keys=True, separators=(",", ":")).encode()
    core["receipt_sha256"] = hashlib.sha256(receipt_payload).hexdigest()
    return core


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scope", required=True, choices=FAMILY_ORDER + ["FINAL"])
    parser.add_argument("--pod-id", required=True, type=int, choices=range(1, 21))
    parser.add_argument("--student-name", required=True)
    parser.add_argument("--student-account", required=True)
    parser.add_argument("--verification-jobs", required=True, help="JSON family-to-AWX-job mapping")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--sample", action="store_true", help="Generate a local review sample without AWX validation")
    return parser.parse_args()


def main():
    args = parse_args()
    if len(args.student_name.strip()) < 2:
        raise ValueError("student name is required")
    try:
        args.student_name.encode("cp1252")
    except UnicodeEncodeError as exc:
        raise ValueError("student name contains characters unsupported by the certificate font") from exc
    valid_account = (
        len(args.student_account) == 9
        and args.student_account.startswith("student")
        and args.student_account[7:].isdigit()
    )
    if not valid_account:
        raise ValueError("student account must use the studentNN format")
    verification_jobs = json.loads(args.verification_jobs)
    pod_key = "pod%02d" % args.pod_id
    if args.sample:
        families = FAMILY_ORDER if args.scope == "FINAL" else [args.scope]
        verified_jobs = {family: int(verification_jobs.get(family, 0)) for family in families}
        completed_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    else:
        host = os.environ.get("CRC_AWX_HOST") or os.environ.get("AWX_HOST", "")
        token = os.environ.get("CRC_AWX_TOKEN") or os.environ.get("AWX_TOKEN", "")
        if not host or not token:
            raise ValueError("CRC_AWX_HOST and CRC_AWX_TOKEN are required")
        verified_jobs, completed_at = verify_completion(
            host, token, pod_key, args.scope, verification_jobs
        )

    receipt = build_receipt(args, verified_jobs, completed_at)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    stem = "DRCC_%s_Pod%02d" % (args.scope, args.pod_id)
    pdf_path = output_dir / (stem + "_Certificate.pdf")
    json_path = output_dir / (stem + "_Receipt.json")
    json_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    make_pdf(pdf_path, receipt)
    print(json.dumps({
        "certificate_id": receipt["certificate_id"],
        "pdf": str(pdf_path),
        "receipt": str(json_path),
        "receipt_sha256": receipt["receipt_sha256"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        sys.exit(1)
