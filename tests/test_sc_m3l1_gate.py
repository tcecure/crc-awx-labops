"""SC-M3-L1 must need the student's audit record, not just a clean ruleset.

Deleting the any/any rule belongs to M1-L2, so the gateway's PASS:RulesClean
alone credited M3-L1 to anyone who did M1-L2. The lab is now graded on both the
gateway check and SC-M3-L1_Completed.txt; these tests pin that wiring in place.
"""
import unittest
from pathlib import Path

import yaml
from jinja2 import Environment

ROOT = Path(__file__).resolve().parents[1]
PLAYBOOK = yaml.safe_load((ROOT / "playbooks" / "verify-cmmc-sc.yml").read_text())
DC_TASKS = yaml.safe_load((ROOT / "roles" / "verify_sc_dc" / "tasks" / "main.yml").read_text())


def merge_expression():
    for play in PLAYBOOK:
        for task in play.get("tasks", []):
            fact = task.get("ansible.builtin.set_fact", {})
            if "pod_results_pub" in fact:
                return fact["pod_results_pub"]
    raise AssertionError("no pod_results_pub set_fact in the SC playbook")


def merge(dc, gw):
    env = Environment()
    env.filters["int"] = int
    rendered = env.from_string(merge_expression()).render(
        pod_list=[4],
        crc_target_mode="member_server",
        groups={"crc_shared_dcs": ["dc01"]},
        hostvars={
            "pod04-srv": {"pod04_sc_dc_results": dc},
            "pod04-gw": {"sc_gw_lab_results": gw},
        },
    )
    return eval(rendered)["pod04"]  # noqa: S307 - Jinja renders a Python literal


CLEAN = {"completed": True, "reason": "PASS:RulesClean"}
RECORD = {"completed": True, "reason": "Rule audit record submitted"}
NO_RECORD = {"completed": False, "reason": "SC-M3-L1_Completed.(txt/csv) not found"}


class ScM3L1GateTests(unittest.TestCase):
    def test_the_dc_role_grades_m3l1_on_the_audit_record(self):
        task = next(t for t in DC_TASKS if "M3-L1" in t["name"])
        script = task["ansible.windows.win_powershell"]["script"]
        self.assertIn("SC-M3-L1_Completed.txt", script)
        results = next(t for t in DC_TASKS if t["name"].startswith("Consolidate"))
        fact = results["ansible.builtin.set_fact"]
        self.assertIn("M3-L1", next(v for k, v in fact.items() if k != "cacheable"))

    def test_clean_ruleset_without_the_record_is_incomplete(self):
        labs = merge({"M3-L1": NO_RECORD}, {"M3-L1": CLEAN})
        self.assertFalse(labs["SC-M3-L1"]["completed"])
        self.assertIn("not found", labs["SC-M3-L1"]["reason"])

    def test_record_plus_clean_ruleset_completes(self):
        labs = merge({"M3-L1": RECORD}, {"M3-L1": CLEAN})
        self.assertTrue(labs["SC-M3-L1"]["completed"])

    def test_record_with_a_dirty_ruleset_is_incomplete(self):
        dirty = {"completed": False, "reason": "FAIL:Issues(1): rule 3 on lan"}
        labs = merge({"M3-L1": RECORD}, {"M3-L1": dirty})
        self.assertFalse(labs["SC-M3-L1"]["completed"])
        self.assertIn("FAIL:Issues", labs["SC-M3-L1"]["reason"])

    def test_unreachable_gateway_does_not_pass_on_the_record_alone(self):
        labs = merge({"M3-L1": RECORD}, {})
        self.assertFalse(labs["SC-M3-L1"]["completed"])
        self.assertIn("gateway unreachable", labs["SC-M3-L1"]["reason"])

    def test_labs_checked_on_one_side_only_are_untouched(self):
        labs = merge({"M1-L1": RECORD}, {"M1-L2": CLEAN})
        self.assertTrue(labs["SC-M1-L1"]["completed"])
        self.assertEqual(labs["SC-M1-L2"]["reason"], "PASS:RulesClean")


if __name__ == "__main__":
    unittest.main()
