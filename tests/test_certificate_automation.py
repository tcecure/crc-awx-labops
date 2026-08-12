import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


advance = load_module("advance_families", ROOT / "scripts" / "advance_families.py")
generator = load_module(
    "generate_completion_certificate",
    ROOT / "scripts" / "generate_completion_certificate.py",
)


class CertificateDecisionTests(unittest.TestCase):
    def test_parse_family_state(self):
        seeded, issued, profiles = advance.parse_family_state([
            r"C:\CyberLab\Pod01\.families\AC.seeded",
            r"C:\CyberLab\Pod01\.certificates\AC.issued",
            r"C:\CyberLab\Pod01\.certificates\FINAL.issued",
            r"C:\CyberLab\Pod01\Certificates\CertificateProfile.json",
        ])
        self.assertEqual(seeded, {"pod01": {"AC"}})
        self.assertEqual(issued, {"pod01": {"FINAL"}})
        self.assertEqual(profiles, {"pod01"})

    def test_completed_family_does_not_create_certificate_action(self):
        jobs = {family: index + 100 for index, family in enumerate(advance.FAMILY_ORDER)}
        actions, pending = advance.decide_certificates(
            {"pod01": {"AC"}}, {}, set(), jobs
        )
        self.assertEqual(actions, [])
        self.assertEqual(pending, [])

    def test_final_award_waits_for_student_name(self):
        jobs = {family: index + 100 for index, family in enumerate(advance.FAMILY_ORDER)}
        actions, pending = advance.decide_certificates(
            {"pod01": set(advance.FAMILY_ORDER)}, {}, set(), jobs
        )
        self.assertEqual(actions, [])
        self.assertEqual(pending, [("pod01", "FINAL")])

    def test_final_award_is_idempotent(self):
        jobs = {family: index + 100 for index, family in enumerate(advance.FAMILY_ORDER)}
        completed = {"pod01": set(advance.FAMILY_ORDER)}
        actions, pending = advance.decide_certificates(
            completed, {}, {"pod01"}, jobs
        )
        self.assertEqual(pending, [])
        self.assertEqual([(pod, scope) for pod, scope, _ in actions], [
            ("pod01", "FINAL"),
        ])
        actions, pending = advance.decide_certificates(
            completed, {"pod01": {"FINAL"}}, {"pod01"}, jobs
        )
        self.assertEqual(actions, [])
        self.assertEqual(pending, [])


class CertificateGenerationTests(unittest.TestCase):
    def test_family_receipt_is_rejected(self):
        args = type("Args", (), {
            "scope": "AC",
            "pod_id": 1,
            "student_name": "Sample Student",
            "student_account": "student09",
        })()
        with self.assertRaisesRegex(ValueError, "only the final"):
            generator.build_receipt(args, {"AC": 1234}, "2026-06-05T12:00:00Z")

    def test_final_receipt_contains_all_families_and_labs(self):
        args = type("Args", (), {
            "scope": "FINAL",
            "pod_id": 20,
            "student_name": "Sample Graduate",
            "student_account": "student17",
        })()
        jobs = {family: index + 200 for index, family in enumerate(generator.FAMILY_ORDER)}
        receipt = generator.build_receipt(args, jobs, "2026-06-05T12:00:00Z")
        self.assertEqual(receipt["families"], generator.FAMILY_ORDER)
        self.assertEqual(len(receipt["labs"]), 57)
        self.assertTrue(receipt["certificate_id"].startswith("DRCC-FINAL-P20-"))
        with tempfile.TemporaryDirectory() as directory:
            pdf_path = Path(directory) / "certificate.pdf"
            generator.make_pdf(pdf_path, receipt)
            self.assertTrue(pdf_path.read_bytes().startswith(b"%PDF-1.4"))
            self.assertGreater(pdf_path.stat().st_size, 1000)
            receipt_path = Path(directory) / "receipt.json"
            receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
            loaded = json.loads(receipt_path.read_text(encoding="utf-8"))
            self.assertEqual(loaded["student_name"], "Sample Graduate")
            self.assertEqual(len(loaded["receipt_sha256"]), 64)


if __name__ == "__main__":
    unittest.main()
