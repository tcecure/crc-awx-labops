"""The AC verifier must not credit labs on a pod that was never seeded.

Several AC labs ask the student to remove misconfigured access, so an unseeded
pod reads exactly like a finished one. The role therefore gates its results on
the AC family marker; these tests pin that wiring in place.
"""
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
ROLE = ROOT / "roles" / "verify_ac_dc"
TASKS = yaml.safe_load((ROLE / "tasks" / "main.yml").read_text())
DEFAULTS = yaml.safe_load((ROLE / "defaults" / "main.yml").read_text())


def task_named(fragment):
    for task in TASKS:
        if fragment in task["name"]:
            return task
    raise AssertionError("no task matching %r" % fragment)


class AcSeedGateTests(unittest.TestCase):
    def test_marker_is_read_before_grading(self):
        marker = task_named("Read the AC family seed marker")
        self.assertEqual(TASKS[0], marker)
        script = marker["ansible.windows.win_powershell"]["script"]
        self.assertIn(r".families\AC.seeded", script)
        self.assertEqual(marker["register"], "v_marker")

    def test_every_graded_lab_has_a_default_id(self):
        graded = task_named("Collect the graded")["ansible.builtin.set_fact"]
        self.assertEqual(sorted(graded["ac_graded_results"]),
                         sorted(DEFAULTS["ac_lab_ids"]))

    def test_results_fall_back_to_incomplete_without_the_marker(self):
        fact = task_named("Consolidate")["ansible.builtin.set_fact"]
        expression = next(v for k, v in fact.items() if k != "cacheable")
        self.assertIn("v_marker.output[0].seeded", expression)
        self.assertIn("ac_lab_ids", expression)
        self.assertIn("ac_unseeded_reason", expression)
        self.assertIn("'completed': false", expression)

    def test_unseeded_reason_names_the_seed_template(self):
        self.assertIn("Seed CMMC AC Labs", DEFAULTS["ac_unseeded_reason"])


if __name__ == "__main__":
    unittest.main()
