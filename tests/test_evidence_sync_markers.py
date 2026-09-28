"""The AC/IA seed markers must survive the evidence round trip.

Both halves of the trip mirror the pod folder with robocopy /MIR. The markers
are written on the domain controller and never exist on the session host, so an
unqualified mirror deletes them from the graded folder and every AC lab then
reports the pod as unseeded.
"""
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
DC_SIDE = ROOT / "playbooks" / "tasks" / "sync-drop-local.yml"
HOST_SIDE = ROOT / "playbooks" / "sync-pod-evidence.yml"
MARKERS = ("AC.seeded", "IA.seeded")


def scripts(path, task_name):
    doc = yaml.safe_load(path.read_text())
    tasks = []
    for entry in doc:
        tasks.extend(entry["tasks"] if "tasks" in entry else [entry])
    for task in tasks:
        if task_name in task["name"]:
            return task["ansible.windows.win_shell"]
    raise AssertionError("no task matching %r in %s" % (task_name, path))


class EvidenceSyncMarkerTests(unittest.TestCase):
    def test_dc_side_mirror_excludes_the_markers(self):
        script = scripts(DC_SIDE, "Move pod evidence on the domain controller")
        self.assertIn("/MIR", script)
        for marker in MARKERS:
            with self.subTest(marker=marker):
                self.assertIn(marker, script.split("/XF", 1)[1])

    def test_session_host_mirror_excludes_the_markers(self):
        script = scripts(HOST_SIDE, "Copy the pod evidence")
        self.assertIn("/MIR", script)
        for marker in MARKERS:
            with self.subTest(marker=marker):
                self.assertIn(marker, script.split("/XF", 1)[1])


if __name__ == "__main__":
    unittest.main()
