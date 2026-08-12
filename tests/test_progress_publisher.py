import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]

VERIFIERS = {
    "verify-cmmc-ac.yml": ("AC", "{{ pod_results }}"),
    "verify-cmmc-ia.yml": ("IA", "{{ pod_results }}"),
    "verify-cmmc-si.yml": ("SI", "{{ pod_results_pub }}"),
    "verify-cmmc-sc.yml": ("SC", "{{ pod_results_pub }}"),
    "verify-cmmc-mp.yml": ("MP", "{{ pod_results_pub }}"),
    "verify-cmmc-pe.yml": ("PE", "{{ pod_results_pub }}"),
}


class ProgressPublisherTests(unittest.TestCase):
    def test_publisher_uses_protected_portal_contract(self):
        tasks = yaml.safe_load(
            (ROOT / "playbooks" / "tasks" / "publish-progress.yml").read_text()
        )
        publish = tasks[0]
        request = publish["ansible.builtin.uri"]

        self.assertTrue(request["url"].endswith("/api/integrations/awx/progress"))
        self.assertEqual(request["method"], "POST")
        self.assertIn("AWX_PROGRESS_SECRET", request["headers"]["Authorization"])
        self.assertEqual(
            set(request["body"]),
            {"family", "verifierJobId", "verifiedAt", "pods"},
        )
        self.assertTrue(request["validate_certs"])
        self.assertTrue(publish["no_log"])
        self.assertFalse(publish["failed_when"])

    def test_every_family_publishes_the_same_results_as_its_awx_artifact(self):
        for filename, (family, pod_results) in VERIFIERS.items():
            with self.subTest(filename=filename):
                plays = yaml.safe_load(
                    (ROOT / "playbooks" / filename).read_text(encoding="utf-8")
                )
                tasks = [
                    task
                    for play in plays
                    for task in play.get("tasks", [])
                    if task.get("ansible.builtin.include_tasks")
                    == "tasks/publish-progress.yml"
                ]

                self.assertEqual(len(tasks), 1)
                self.assertEqual(tasks[0]["vars"]["progress_family"], family)
                self.assertEqual(tasks[0]["vars"]["progress_pods"], pod_results)


if __name__ == "__main__":
    unittest.main()
